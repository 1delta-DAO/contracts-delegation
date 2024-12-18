// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

import {PoolGetterTaiko} from "./PoolGetterTaiko.sol";

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
contract OneDeltaQuoterTaiko is PoolGetterTaiko {
    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;
    uint256 internal constant UINT16_MASK = 0xffff;
    uint256 internal constant SCALE_18 = 1e18;
    uint256 internal constant UINT8_MASK = 0xff;

    uint256 internal constant CL_PARAM_LENGTH = 43; // token + id + pool + fee
    uint256 internal constant V2_PARAM_LENGTH = CL_PARAM_LENGTH; // token + id + pool
    uint256 internal constant EXOTIC_PARAM_LENGTH = 41; // token + id + pool
    uint256 internal constant CURVE_PARAM_LENGTH = CL_PARAM_LENGTH + 1; // token + id + pool + idIn + idOut + empty_u8

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

    // uniswap & DTX
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // pancakes
    function pancakeV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    // algebras
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view {
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
                pair := calldataload(add(path.offset, 9)) // pool starts at 21st byte
            }
            // v3 types
            if (poolId < 49) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountIn = quoteExactInputSingleV3(tokenIn, tokenOut, pair, amountIn);
                path = path[CL_PARAM_LENGTH:];
            }
            // iZi
            else if (poolId == 49) {
                assembly {
                    // tokenOut starts at 43th byte for CL
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountIn = quoteExactInputSingle_iZi(tokenIn, tokenOut, pair, uint128(amountIn));
                path = path[CL_PARAM_LENGTH:];
            }
            // curve
            else if (poolId == 60) {
                uint8 indexIn;
                uint8 indexOut;
                assembly {
                    let indexData := calldataload(add(path.offset, 21))
                    indexIn := and(shr(88, indexData), 0xff)
                    indexOut := and(shr(80, indexData), 0xff)
                }
                amountIn = quoteCurveGeneral(indexIn, indexOut, pair, amountIn);
                path = path[CURVE_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < 150) {
                uint256 feeDenom;
                assembly {
                    // tokenOut starts at 43rd byte
                    tokenOut := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                    feeDenom := and(UINT16_MASK, shr(80, calldataload(add(path.offset, 21))))
                }
                amountIn = getAmountOutUniV2Type(pair, tokenIn, tokenOut, amountIn, feeDenom, poolId);
                path = path[V2_PARAM_LENGTH:];
            } else if (poolId == 150) {
                amountIn = quoteSyncSwapExactIn(pair, tokenIn, amountIn);
                path = path[EXOTIC_PARAM_LENGTH:];
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
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountOut = quoteExactOutputSingleV3(tokenIn, tokenOut, pair, amountOut);
                path = path[CL_PARAM_LENGTH:];
            } else if (poolId == 49) {
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                }
                amountOut = quoteExactOutputSingle_iZi(tokenIn, tokenOut, pair, uint128(amountOut));
                path = path[CL_PARAM_LENGTH:];
            }
            // v2 types
            else if (poolId < 150) {
                uint256 feeDenom;
                assembly {
                    // tokenIn starts at 43th byte for CL
                    tokenIn := shr(96, calldataload(add(path.offset, CL_PARAM_LENGTH)))
                    feeDenom := and(UINT16_MASK, shr(80, calldataload(add(path.offset, 21))))
                }
                amountOut = getV2AmountInDirect(pair, tokenIn, tokenOut, amountOut, feeDenom, poolId);
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
        uint256 feeDenom,
        uint256 _pId // to identify the fee
    ) internal view returns (uint256 buyAmount) {
        assembly {
            // Compute the buy amount based on the pair reserves.
            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch lt(_pId, 120)
                case 1 {
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
                    let sellAmountWithFee := mul(sellAmount, feeDenom)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 10000)))
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

    function quoteCurveGeneral(uint256 indexIn, uint256 indexOut, address pool, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            // selector for get_dy(uint256,uint256,uint256)
            mstore(0xB00, 0x556d6e9f00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            if iszero(staticcall(gas(), pool, 0xB00, 0x64, 0xB00, 0x20)) {
                revert(0, 0)
            }

            amountOut := mload(0xB00)
        }
    }

    function quoteSyncSwapExactIn(address pair, address tokenIn, uint256 amountIn) internal view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // selector for getAmountOut(address,uint256,address)
            mstore(ptr, 0xff9c8ac600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), amountIn)
            mstore(add(ptr, 0x44), 0x0)
            if iszero(staticcall(gas(), pair, ptr, 0x64, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Calculates the input amount for a UniswapV2 and Solidly style swap
     * This function is separate from the swapper because it is needed
     * in the spot case where we iteratively execute swaps between the
     * calculation of the amount and the execution of the v2 swap.
     * Compatible with solidly stable swaps.
     * We assume that the pair address is already provided.
     * We split dexIds
     * -> 100-135: Uniswap V2 / Solidly Volatile
     * -> 135-150: Solidly Stable
     * @param pair provided pair address
     * @param tokenIn input
     * @param tokenOut output
     * @param buyAmount output amunt
     * @param pId DEX identifier
     * @return x input amount
     */
    function getV2AmountInDirect(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 feeDenom,
        uint256 pId // poolId
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `screp space`
            mstore(0x0, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
            if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // Revert if the pair contract does not return at least two words.
            if lt(returndatasize(), 0x40) {
                revert(0, 0)
            }

            // Compute the sell amount based on the pair reserves.
            {
                switch lt(pId, 135)
                case 1 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0x20)
                        buyReserve := mload(0x0)
                    }
                    default {
                        sellReserve := mload(0x0)
                        buyReserve := mload(0x20)
                    }
                    // we ensure that the pair has enough funds
                    if gt(buyAmount, buyReserve) {
                        revert(0, 0)
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                feeDenom // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // covers solidly forks for stable pools (>=135)
                default {
                    let _decimalsIn
                    let _decimalsOut_xy
                    let y0
                    let _reserveInScaled
                    // scope for scaled reserves
                    {
                        /////////////////////////////////////////////////////////////
                        // We fetch the decimals of the tokens to compute the curve
                        // style logic we do this in the scrap space
                        /////////////////////////////////////////////////////////////
                        // selector for decimals()
                        mstore(0x0, 0x313ce56700000000000000000000000000000000000000000000000000000000)
                        pop(staticcall(gas(), tokenIn, 0x0, 0x4, 0x4, 0x20))
                        _decimalsIn := exp(10, mload(0x4))
                        pop(staticcall(gas(), tokenOut, 0x0, 0x4, 0x4, 0x20))
                        _decimalsOut_xy := exp(10, mload(0x4))

                        // Call pair.getReserves(), store the results in scrap space
                        mstore(0x0, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                        if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
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
                            _reserveInScaled := div(mul(mload(0x0), SCALE_18), _decimalsIn)
                            let buyReserve := mload(0x20)
                            // we ensure that the pair has enough funds
                            if gt(buyAmount, buyReserve) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(buyReserve, SCALE_18), _decimalsOut_xy)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(0x20), SCALE_18), _decimalsIn)
                            let buyReserve := mload(0x0)
                            // we ensure that the pair has enough funds
                            if gt(buyAmount, buyReserve) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(buyReserve, SCALE_18), _decimalsOut_xy)
                        }
                        y0 := sub(_reserveOutScaled, div(mul(buyAmount, SCALE_18), _decimalsOut_xy))
                        x := _reserveInScaled
                        // get xy
                        _decimalsOut_xy := div(
                            mul(
                                div(mul(_reserveInScaled, _reserveOutScaled), SCALE_18),
                                add(
                                    div(mul(_reserveInScaled, _reserveInScaled), SCALE_18), //
                                    div(mul(_reserveOutScaled, _reserveOutScaled), SCALE_18)
                                )
                            ),
                            SCALE_18
                        )
                    }
                    // for-loop for approximation
                    let i := 0
                    for {

                    } lt(i, 255) {

                    } {
                        let x_prev := x
                        let k := add(
                            div(mul(x, div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)), SCALE_18),
                            div(mul(y0, div(mul(div(mul(x, x), SCALE_18), x), SCALE_18)), SCALE_18)
                        )
                        switch lt(k, _decimalsOut_xy)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy, k), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
                                        div(
                                            mul(div(mul(y0, y0), SCALE_18), y0), //
                                            SCALE_18
                                        )
                                    )
                                )
                            )
                        }
                        default {
                            x := sub(
                                x,
                                div(
                                    mul(sub(k, _decimalsOut_xy), SCALE_18),
                                    add(
                                        div(
                                            mul(mul(3, y0), div(mul(x, x), SCALE_18)), //
                                            SCALE_18
                                        ),
                                        div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)
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
                    // calculate and adjust the result (reserveInNew - reserveIn) * 10k / (10k - fee)
                    x := add(
                        div(
                            div(
                                mul(mul(sub(x, _reserveInScaled), _decimalsIn), 10000),
                                feeDenom // 10000 - fee
                            ),
                            SCALE_18
                        ),
                        1 // rounding up
                    )
                }
            }
        }
    }
}
