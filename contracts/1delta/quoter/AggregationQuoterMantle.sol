// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.26;

import {PoolGetter} from "./PoolGetter.sol";

interface ISwapPool {
    function swap(
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);

    /** IZUMI */

    function swapY2X(
        // exact in swap token1 to 0
        address recipient,
        uint128 amount,
        int24 highPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapY2XDesireX(
        // exact out swap token1 to 0
        address recipient,
        uint128 desireX,
        int24 highPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapX2Y(
        // exact in swap token0 to 1
        address recipient,
        uint128 amount,
        int24 lowPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);

    function swapX2YDesireY(
        // exact out swap token0 to 1
        address recipient,
        uint128 desireY,
        int24 lowPt,
        bytes calldata data
    ) external returns (uint256 amountX, uint256 amountY);
}

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
contract OneDeltaQuoterMantle is PoolGetter {
    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    uint256 internal constant CL_PARAM_LENGTH = 43; // token + id + pool + fee
    uint256 internal constant V2_PARAM_LENGTH = 41; // token + id + pool
    uint256 internal constant CURVE_PARAM_LENGTH = CL_PARAM_LENGTH; // token + id + pool + idIn + idOut
    uint256 internal constant CURVE_CUSTOM_PARAM_LENGTH = 21; // no pool address provided

    function quoteKTXExactIn(address _tokenIn, address _tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let ptrPlus4 := add(ptr, 0x4)
            ////////////////////////////////////////////////////
            // Step 1: get prices
            ////////////////////////////////////////////////////

            // getPrice(address,bool,bool,bool)
            mstore(ptr, 0x2fc3a70a00000000000000000000000000000000000000000000000000000000)
            // get maxPrice
            mstore(ptrPlus4, _tokenOut)
            mstore(add(ptr, 0x24), 0x1)
            mstore(add(ptr, 0x44), 0x1)
            mstore(add(ptr, 0x64), 0x1)
            pop(
                staticcall(
                    gas(),
                    KTX_VAULT_PRICE_FEED, // this goes to the oracle
                    ptr,
                    0x84,
                    ptrPlus4, // do NOT override the selector
                    0x20
                )
            )
            let priceOut := mload(ptrPlus4)
            // get minPrice
            mstore(ptrPlus4, _tokenIn)
            mstore(add(ptr, 0x24), 0x0)
            // the other vars are stored from the prior call
            pop(
                staticcall(
                    gas(),
                    KTX_VAULT_PRICE_FEED, // this goes to the oracle
                    ptr,
                    0x84,
                    ptr,
                    0x20
                )
            )
            let priceIn := mload(ptr)

            ////////////////////////////////////////////////////
            // Step 2: get amountOut by prices
            ////////////////////////////////////////////////////

            // get gross amountOut unscaled
            amountOut := div(mul(amountIn, priceIn), priceOut)

            ////////////////////////////////////////////////////
            // Step 3: get token decimals and adjust amountOut
            ////////////////////////////////////////////////////

            // selector for decimals()
            mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), _tokenIn, ptr, 0x4, ptrPlus4, 0x20))
            let decsIn := exp(10, mload(ptrPlus4))
            pop(staticcall(gas(), _tokenOut, ptr, 0x4, ptrPlus4, 0x20))
            let decsOut := exp(10, mload(ptrPlus4))
            // adjust amountOut for correct decimals
            amountOut := div(mul(amountOut, decsOut), decsIn)

            ////////////////////////////////////////////////////
            // Step 4: calculate fees
            //      4.1: get usdg amount
            //      4.2: get getSwapFeeBasisPoints
            ////////////////////////////////////////////////////
            let usdgAmount := div(
                mul(
                    div(
                        mul(amountIn, priceIn), // price adj
                        PRICE_PRECISION
                    ),
                    1000000000000000000 // 1e18
                ),
                decsIn
            )
            // getSwapFeeBasisPoints(address,address,uint256)
            mstore(ptr, 0xda13381600000000000000000000000000000000000000000000000000000000)
            mstore(ptrPlus4, _tokenIn)
            mstore(add(ptr, 0x24), _tokenOut)
            mstore(add(ptr, 0x44), usdgAmount)

            pop(staticcall(gas(), KTX_VAULT_UTILS, ptr, 0x64, ptr, 0x20))
            ////////////////////////////////////////////////////
            // Step 5: get net return amount and validate vs. vault balance
            ////////////////////////////////////////////////////
            amountOut := div(
                mul(
                    amountOut, //  * decsOut / decsIn
                    sub(10000, mload(ptr))
                ),
                10000
            )

            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, KTX_VAULT)

            // call to tokenOut to fetch balance
            if iszero(staticcall(gas(), _tokenOut, 0x0, 0x24, 0x0, 0x20)) {
                revert(0, 0)
            }
            // vault must have enough liquidity
            if lt(mload(0x0), amountOut) {
                revert(0, 0)
            }
        }
    }

    constructor() {}

    // uniswap V3 type callback
    function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) internal view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }

        (bool isExactInput, uint256 amountToPay, uint256 amountReceived) = amount0Delta > 0
            ? (tokenIn < tokenOut, uint256(amount0Delta), uint256(-amount1Delta))
            : (tokenOut < tokenIn, uint256(amount1Delta), uint256(-amount0Delta));

        if (isExactInput) {
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountReceived)
                revert(ptr, 32)
            }
        } else {
            // if the cache has been populated, ensure that the full output amount has been received
            if (amountOutCached != 0) require(amountReceived >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                revert(ptr, 32)
            }
        }
    }

    // fusionx v3
    function fusionXV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // methlab
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // agni
    function agniSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    //butter
    function butterSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, _data);
    }

    // swapsicle
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // Cleo
    function ramsesV2SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // iZi callbacks

    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }
        if (tokenIn < tokenOut) {
            // token1 is y, amount of token1 is calculated
            // called from swapY2XDesireX(...)
            if (amountOutCached != 0) require(x >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, y)
                revert(ptr, 64)
            }
        } else {
            // token0 is y, amount of token0 is input param
            // called from swapY2X(...)
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, x)
                revert(ptr, 64)
            }
        }
    }

    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 20))) // we load starting from the 2nd token and slice the rest
        }
        if (tokenIn < tokenOut) {
            // token0 is x, amount of token0 is input param
            // called from swapX2Y(...)
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, y)
                revert(ptr, 64)
            }
        } else {
            // token1 is x, amount of token1 is calculated param
            // called from swapX2YDesireY(...)
            if (amountOutCached != 0) require(y >= amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, x)
                revert(ptr, 64)
            }
        }
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason) internal pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // iZi catches errors of length other than 64 internally
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
    }

    function quoteExactInputSingleV3(address tokenIn, address tokenOut, address pair, uint256 amountIn) internal returns (uint256 amountOut) {
        bool zeroForOne = tokenIn < tokenOut;

        try
            ISwapPool(pair).swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                abi.encodePacked(tokenIn, tokenOut)
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function quoteExactInputSingle_iZi(
        // no pool identifier
        address tokenIn,
        address tokenOut,
        address pair,
        uint128 amount
    ) internal returns (uint256 amountOut) {
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try
                ISwapPool(pair).swapX2Y(
                    address(this), // address(0) might cause issues with some tokens
                    amount,
                    boundaryPoint,
                    abi.encodePacked(tokenIn, tokenOut)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try
                ISwapPool(pair).swapY2X(
                    address(this), // address(0) might cause issues with some tokens
                    amount,
                    boundaryPoint,
                    abi.encodePacked(tokenIn, tokenOut)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }

    function quoteExactOutputSingleV3(address tokenIn, address tokenOut, address pair, uint256 amountOut) internal returns (uint256 amountIn) {
        bool zeroForOne = tokenIn < tokenOut;

        // if no price limit has been specified, cache the output amount for comparison in the swap callback
        amountOutCached = amountOut;
        try
            ISwapPool(pair).swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                -int256(amountOut),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                abi.encodePacked(tokenOut, tokenIn)
            )
        {} catch (bytes memory reason) {
            delete amountOutCached; // clear cache
            return parseRevertReason(reason);
        }
    }

    function quoteExactOutputSingle_iZi(
        // no pool identifier, using `desire` functions fir exact out
        address tokenIn,
        address tokenOut,
        address pair,
        uint128 desire
    ) internal returns (uint256 amountIn) {
        amountOutCached = desire;
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try
                ISwapPool(pair).swapX2YDesireY(
                    address(this), // address(0) might cause issues with some tokens
                    desire + 1,
                    boundaryPoint,
                    abi.encodePacked(tokenOut, tokenIn)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try
                ISwapPool(pair).swapY2XDesireX(
                    address(this), // address(0) might cause issues with some tokens
                    desire + 1,
                    boundaryPoint,
                    abi.encodePacked(tokenOut, tokenIn)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }

    function getLBAmountOut(
        address tokenOut,
        uint256 amountIn,
        address pair // identifies the exact pair address
    ) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // invalid pairs will make it fail here
                staticcall(gas(), pair, ptr, 0x4, ptr, 0x20)
            ) {
                revert(0, 0)
            }
            // override swapForY
            let swapForY := eq(tokenOut, mload(ptr))
            // getSwapOut(uint128,bool)
            mstore(ptr, 0xe77366f800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountIn)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) {
                revert(0, 0)
            }
            amountOut := and(
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                mload(add(ptr, 0x20))
            )
            // the first slot returns amount in left, if positive, we revert
            if gt(mload(ptr), 0) {
                revert(0, 0)
            }
        }
    }

    function getLBAmountIn(
        address tokenOut,
        uint256 amountOut,
        address pair // this param identifies the pair
    ) internal view returns (uint256 amountIn) {
        assembly {
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, pair)

            // call to underlying
            if iszero(staticcall(gas(), tokenOut, 0x0, 0x24, 0x0, 0x20)) {
                revert(0, 0)
            }
            // pair must have enough liquidity
            if lt(mload(0x0), amountOut) {
                revert(0, 0)
            }

            let ptr := mload(0x40)
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(gas(), pair, ptr, 0x4, ptr, 0x20)
            )
            // override swapForY
            let swapForY := eq(tokenOut, mload(ptr))
            // getSwapIn(uint128,bool)
            mstore(ptr, 0xabcd783000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountOut)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) {
                revert(0, 0)
            }
            amountIn := and(
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                mload(ptr)
            )
            // the second slot returns amount out left, if positive, we revert
            if gt(mload(add(ptr, 0x20)), 0) {
                revert(0, 0)
            }
        }
    }

    /************************************************** Mixed **************************************************/

    /// @dev Get the quote for an exactIn swap between an array of Stable, V2 and/or V3 pools
    function quoteExactInput(
        bytes calldata path, // calldata more efficient than memory
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        while (true) {
            address tokenIn;
            address tokenOut;
            address pair;
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord) // get first token
                poolId := shr(88, firstWord) //
                pair := shr(96, calldataload(add(path.offset, 21))) // pool starts at 21st byte
            }

            // v3 types
            if (poolId < 49) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, 43)))
                }
                amountIn = quoteExactInputSingleV3(tokenIn, tokenOut, pair, amountIn);
                path = path[CL_PARAM_LENGTH:];
            }
            // iZi
            else if (poolId == 49) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, 43)))
                }
                amountIn = quoteExactInputSingle_iZi(tokenIn, tokenOut, pair, uint128(amountIn));
                path = path[CL_PARAM_LENGTH:];
            } else if (poolId == 50) {
                assembly {
                    // need to re-assign token out for stratum
                    tokenOut := shr(96, calldataload(add(path.offset, 21)))
                }
                amountIn = quoteStratum3(tokenIn, tokenOut, amountIn);
                path = path[CURVE_CUSTOM_PARAM_LENGTH:];
            } else if (poolId == 51) {
                uint8 indexIn;
                uint8 indexOut;
                assembly {
                    let indexData := calldataload(add(path.offset, 21))
                    indexIn := and(shr(88, indexData), 0xff)
                    indexOut := and(shr(80, indexData), 0xff)
                }
                amountIn = quoteStratumGeneral(indexIn, indexOut, pair, amountIn);
                path = path[CURVE_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < 150) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = getAmountOutUniV2Type(pair, tokenIn, tokenOut, amountIn, poolId);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == 150) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = quoteWOO(tokenIn, tokenOut, amountIn);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == 151) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = getLBAmountOut(tokenOut, amountIn, pair);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == 152) {
                assembly {
                    // tokenOut starts at 41st byte
                    tokenOut := shr(96, calldataload(add(path.offset, 41)))
                }
                amountIn = quoteKTXExactIn(tokenIn, tokenOut, amountIn);
                path = path[V2_PARAM_LENGTH:];
            } else {
                revert invalidDexId();
            }

            /// decide whether to continue or terminate
            if (path.length < 40) {
                return amountIn;
            }
        }
    }

    /// @dev Get the quote for an exactIn swap between an array of Stable, V2 and/or V3 pools
    function quoteExactOutput(
        bytes calldata path, // calldata more efficient than memory
        uint256 amountOut
    ) public returns (uint256 amountIn) {
        while (true) {
            address tokenIn;
            address tokenOut;
            uint8 poolId;
            address pair;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord) // get first token
                poolId := shr(88, firstWord) //
                pair := shr(96, calldataload(add(path.offset, 21))) //
            }

            // v3 types
            if (poolId < 49) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, 43)))
                }
                amountOut = quoteExactOutputSingleV3(tokenIn, tokenOut, pair, amountOut);
                path = path[CL_PARAM_LENGTH:];
            } else if (poolId == 49) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, 43)))
                }
                amountOut = quoteExactOutputSingle_iZi(tokenIn, tokenOut, pair, uint128(amountOut));
                path = path[CL_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < 150) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, 41)))
                }
                amountOut = getV2AmountInDirect(pair, tokenIn, tokenOut, amountOut, poolId);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == 151) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, 41)))
                }
                amountOut = getLBAmountIn(tokenOut, amountOut, pair);
                path = path[V2_PARAM_LENGTH:];
            } else {
                revert invalidDexId();
            }
            /// decide whether to continue or terminate
            if (path.length < 40) {
                return amountOut;
            }
        }
    }

    /// @dev calculate amountOut for uniV2 style pools - does not require overflow checks
    function getAmountOutUniV2Type(
        address pair,
        address tokenIn, // only used for solidly forks
        address tokenOut,
        uint256 sellAmount,
        uint256 _pId // to identify the fee
    ) internal view returns (uint256 buyAmount) {
        assembly {
            // Compute the buy amount based on the pair reserves.
            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch _pId
                case 100 {
                    // Call pair.getReserves(), store the results at `0xC00`
                    mstore(0xB00, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x4, 0xC00, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) {
                        revert(0, 0)
                    }

                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // fusionX v2 feeAm: 998
                    let sellAmountWithFee := mul(sellAmount, 998)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                // merchant moe
                case 101 {
                    // Call pair.getReserves(), store the results at `0xC00`
                    mstore(0xB00, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x4, 0xC00, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) {
                        revert(0, 0)
                    }

                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // merchant moe feeAm: 997
                    let sellAmountWithFee := mul(sellAmount, 997)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                // covers solidly: velo volatile, stable and cleo V1 volatile, stable, stratum volatile, stable
                default {
                    // selector for getAmountOut(uint256,address)
                    mstore(0xB00, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(0xB04, sellAmount)
                    mstore(0xB24, tokenIn)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x44, 0xB00, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    buyAmount := mload(0xB00)
                }
            }
        }
    }

    function quoteWOO(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            // selector for querySwap(address,address,uint256)
            mstore(0xB00, 0xe94803f400000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, tokenIn)
            mstore(0xB24, tokenOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), WOO_ROUTER, 0xB00, 0x64, 0xB00, 0x20)) {
                revert(0, 0)
            }

            amountOut := mload(0xB00)
        }
    }

    function quoteStratum3(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let indexIn
            let indexOut
            switch tokenIn
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {
                // calculate USDY->mUSD wrap
                // selector for getRUSDYByShares(uint256)
                mstore(0xB00, 0xbc0ca91500000000000000000000000000000000000000000000000000000000)

                mstore(0xB04, amountIn)
                if iszero(staticcall(gas(), MUSD, 0xB00, 0x24, 0xB00, 0x20)) {
                    revert(0, 0)
                }
                amountIn := mul(mload(0xB00), 10000)
                indexIn := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexIn := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexIn := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexIn := 2
            }
            default {
                revert(0, 0)
            }

            switch tokenOut
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {
                indexOut := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexOut := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexOut := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexOut := 2
            }
            default {
                revert(0, 0)
            }
            // selector for calculateSwap(uint8,uint8,uint256)
            mstore(0xB00, 0xa95b089f00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), STRATUM_3POOL, 0xB00, 0x64, 0xB00, 0x20)) {
                revert(0, 0)
            }

            amountOut := mload(0xB00)

            if eq(tokenOut, USDY) {
                // calculate mUSD->USDY unwrap
                // selector for getSharesByRUSDY(uint256)
                mstore(0xB00, 0xb15f291e00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, amountOut)
                if iszero(staticcall(gas(), MUSD, 0xB00, 0x24, 0xB00, 0x20)) {
                    revert(0, 0)
                }
                amountOut := div(mload(0xB00), 10000)
            }
        }
    }

    function quoteStratumGeneral(uint256 indexIn, uint256 indexOut, address pool, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            // selector for calculateSwap(uint8,uint8,uint256)
            mstore(0xB00, 0xa95b089f00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), pool, 0xB00, 0x64, 0xB00, 0x20)) {
                revert(0, 0)
            }

            amountOut := mload(0xB00)
        }
    }

    /// @dev calculates the input amount for a UniswapV2 style swap - requires overflow checks
    function getV2AmountInDirect(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 pId // poolId
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `free memo`
            mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
            if iszero(staticcall(gas(), pair, ptr, 0x4, ptr, 0x40)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // Revert if the pair contract does not return at least two words.
            if lt(returndatasize(), 0x40) {
                revert(0, 0)
            }

            // Compute the sell amount based on the pair reserves.
            {
                switch pId
                case 100 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }
                    default {
                        buyReserve := mload(ptr)
                        sellReserve := mload(add(ptr, 0x20))
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feeAm is 998 for fusionX
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 998)), 1)
                }
                case 101 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }
                    default {
                        buyReserve := mload(ptr)
                        sellReserve := mload(add(ptr, 0x20))
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feAm is 997 for Moe
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 997)), 1)
                }
                // velocimeter volatile
                case 121 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }
                    default {
                        buyReserve := mload(ptr)
                        sellReserve := mload(add(ptr, 0x20))
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }
                    // fetch the fee from the factory
                    // selector for getFee(address)
                    mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), pair)
                    pop(staticcall(gas(), VELO_FACTORY, ptr, 0x24, ptr, 0x20))
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, mload(ptr)) // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // stratum volatile (same as velo, just different addresses)
                case 125 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }
                    default {
                        buyReserve := mload(ptr)
                        sellReserve := mload(add(ptr, 0x20))
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }
                    // fetch the fee from the factory
                    // selector for getFee(address)
                    mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), pair)
                    pop(staticcall(gas(), STRATUM_FACTORY, ptr, 0x24, ptr, 0x20))
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, mload(ptr)) // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // cleo volatile
                case 123 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }
                    default {
                        buyReserve := mload(ptr)
                        sellReserve := mload(add(ptr, 0x20))
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }
                    // fetch the fee from the factory
                    // selector for pairFee(address)
                    mstore(ptr, 0x841fa66b00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), pair)
                    pop(staticcall(gas(), CLEO_V1_FACTORY, ptr, 0x24, ptr, 0x20))
                    let fee := mload(ptr)
                    // if the fee is zero, it will be overridden by the default ones
                    if iszero(fee) {
                        // selector for volatileFee()
                        mstore(ptr, 0x5084ed0300000000000000000000000000000000000000000000000000000000)
                        pop(staticcall(gas(), CLEO_V1_FACTORY, ptr, 0x24, ptr, 0x20))
                        fee := mload(ptr)
                    }
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, fee) // adjust for Cleo fee
                            )
                        ),
                        1
                    )
                }
                // covers solidly forks for stable pools (53, 55, 57)
                default {
                    let _decimalsIn
                    let y0
                    let _reserveInScaled
                    let _decimalsOut_xy_fee
                    {
                        {
                            let ptrPlus4 := add(ptr, 0x4)
                            // selector for decimals()
                            mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)
                            pop(staticcall(gas(), tokenIn, ptr, 0x4, ptrPlus4, 0x20))
                            _decimalsIn := exp(10, mload(ptrPlus4))
                            pop(staticcall(gas(), tokenOut, ptr, 0x4, ptrPlus4, 0x20))
                            _decimalsOut_xy_fee := exp(10, mload(ptrPlus4))
                        }

                        // Call pair.getReserves(), store the results at `free memo`
                        mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                        if iszero(staticcall(gas(), pair, ptr, 0x4, ptr, 0x40)) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        // Revert if the pair contract does not return at least two words.
                        if lt(returndatasize(), 0x40) {
                            revert(0, 0)
                        }
                        // assign reserves to in/out
                        let _reserveOutScaled
                        switch lt(tokenIn, tokenOut)
                        case 1 {
                            _reserveInScaled := div(mul(mload(ptr), 1000000000000000000), _decimalsIn)
                            let reserveOut := mload(add(ptr, 0x20))
                            // revert if insufficient reserves
                            if lt(reserveOut, buyAmount) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(reserveOut, 1000000000000000000), _decimalsOut_xy_fee)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(add(ptr, 0x20)), 1000000000000000000), _decimalsIn)
                            let reserveOut := mload(ptr)
                            // revert if insufficient reserves
                            if lt(reserveOut, buyAmount) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(reserveOut, 1000000000000000000), _decimalsOut_xy_fee)
                        }

                        y0 := sub(_reserveOutScaled, div(mul(buyAmount, 1000000000000000000), _decimalsOut_xy_fee))
                        x := _reserveInScaled
                        // get xy
                        _decimalsOut_xy_fee := div(
                            mul(
                                div(mul(_reserveInScaled, _reserveOutScaled), 1000000000000000000),
                                add(
                                    div(mul(_reserveInScaled, _reserveInScaled), 1000000000000000000),
                                    div(mul(_reserveOutScaled, _reserveOutScaled), 1000000000000000000)
                                )
                            ),
                            1000000000000000000
                        )
                    }
                    // for-loop for approximation
                    let i := 0
                    for {

                    } lt(i, 255) {

                    } {
                        let x_prev := x
                        let k := add(
                            div(mul(x, div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)), 1000000000000000000),
                            div(mul(y0, div(mul(div(mul(x, x), 1000000000000000000), x), 1000000000000000000)), 1000000000000000000)
                        )
                        switch lt(k, _decimalsOut_xy_fee)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy_fee, k), 1000000000000000000),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), 1000000000000000000)), 1000000000000000000),
                                        div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)
                                    )
                                )
                            )
                        }
                        default {
                            x := sub(
                                x,
                                div(
                                    mul(sub(k, _decimalsOut_xy_fee), 1000000000000000000),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), 1000000000000000000)), 1000000000000000000),
                                        div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)
                                    )
                                )
                            )
                        }
                        switch gt(x, x_prev)
                        case 1 {
                            if lt(sub(x, x_prev), 2) {
                                break
                            }
                        }
                        default {
                            if lt(sub(x_prev, x), 2) {
                                break
                            }
                        }
                        i := add(i, 1)
                    }
                    // fetch the fee from the factory
                    switch pId
                    // cleo stable
                    case 124 {
                        // selector for pairFee(address)
                        mstore(ptr, 0x841fa66b00000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x4), pair)
                        pop(staticcall(gas(), CLEO_V1_FACTORY, ptr, 0x24, ptr, 0x20))
                        // store fee in param
                        _decimalsOut_xy_fee := mload(ptr)
                        // if the fee is zero, it is overridden by the stableFee default
                        if iszero(_decimalsOut_xy_fee) {
                            // selector for stableFee()
                            mstore(ptr, 0x40bbd77500000000000000000000000000000000000000000000000000000000)
                            pop(staticcall(gas(), CLEO_V1_FACTORY, ptr, 0x24, ptr, 0x20))
                            _decimalsOut_xy_fee := mload(ptr)
                        }
                    }
                    // velo stable
                    case 122 {
                        // selector for getFee(address)
                        mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x4), pair)
                        pop(staticcall(gas(), VELO_FACTORY, ptr, 0x24, ptr, 0x20))
                        _decimalsOut_xy_fee := mload(ptr)
                    }
                    // Stratum stable
                    default {
                        // selector for getFee(address)
                        mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x4), pair)
                        pop(staticcall(gas(), STRATUM_FACTORY, ptr, 0x24, ptr, 0x20))
                        _decimalsOut_xy_fee := mload(ptr)
                    }
                    // calculate and adjust the result (reserveInNew - reserveIn) * 10k / (10k - fee)
                    x := add(
                        div(
                            div(
                                mul(mul(sub(x, _reserveInScaled), _decimalsIn), 10000),
                                sub(10000, _decimalsOut_xy_fee) // 10000 - fee
                            ),
                            1000000000000000000
                        ),
                        1 // rounding up
                    )
                }
            }
        }
    }
}
