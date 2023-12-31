// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.23;

interface ISwapPool {
    function swap(
        address recipient,
        bool zeroToOne,
        int256 amountRequired,
        uint160 limitSqrtPrice,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    function token0() external view returns (address);
}

interface IiZiSwapPool {
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
contract OneDeltaQuoterMantle {
    error tickOutOfRange();
    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    /// @dev Mask of lower 20 bytes.
    uint256 private constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 private constant UINT24_MASK = 0xffffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 private immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 private immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // _FF_ is given as follows: bytes32((uint256(0xff) << 248) | (uint256(uint160(address)) << 88));

    bytes32 private constant FUSION_V3_FF_FACTORY = 0xff8790c2C3BA67223D83C8FCF2a5E3C650059987b40000000000000000000000;
    bytes32 private constant FUSION_POOL_INIT_CODE_HASH = 0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf;

    bytes32 private constant AGNI_V3_FF_FACTORY = 0xffe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d030000000000000000000000;
    bytes32 private constant AGNI_POOL_INIT_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a;

    bytes32 private constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 private constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    bytes32 private constant IZI_FF_FACTORY = 0xff45e5F26451CDB01B0fA1f8582E0aAD9A6F27C2180000000000000000000000;
    bytes32 private constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 private constant ALGEBRA_V3_FF_DEPLOYER = 0xff9dE2dEA5c68898eb4cb2DeaFf357DFB26255a4aa0000000000000000000000;
    bytes32 private constant ALGEBRA_POOL_INIT_CODE_HASH = 0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91;

    bytes32 private constant BUTTER_FF_FACTORY = 0xffeeca0a86431a7b42ca2ee5f479832c3d4a4c26440000000000000000000000;
    bytes32 private constant BUTTER_POOL_INIT_CODE_HASH = 0xc7d06444331e4f63b0764bb53c88788882395aa31961eed3c2768cc9568323ee;

    constructor() {}

    // uniswap V3 type callback
    function _v3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) private view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        uint8 pid;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            pid := shr(64, calldataload(path.offset)) // right shift by 8 = (9 - 1) bytes
            tokenOut := shr(96, calldataload(add(path.offset, 24))) // we load starting from the 2nd token and slice the rest
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

    // iZi callbacks

    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external view {
        // we do not validate the callback since it's just a view function
        // as such, we do not need to decode poolId and fee
        address tokenIn;
        address tokenOut;
        assembly {
            tokenIn := shr(96, calldataload(path.offset)) // right shift by 12 bytes yields the 1st token
            tokenOut := shr(96, calldataload(add(path.offset, 24))) // we load starting from the 2nd token and slice the rest
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
            tokenOut := shr(96, calldataload(add(path.offset, 24))) // we load starting from the 2nd token and slice the rest
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
    function parseRevertReason(bytes memory reason) private pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length != 64) revert("Unexpected error");
            // iZi catches errors of length other than 64 internally
            return abi.decode(reason, (uint256));
        }
        return abi.decode(reason, (uint256));
    }

    function quoteExactInputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint8 pId, // pool identifier
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        bool zeroForOne = tokenIn < tokenOut;

        try
            v3TypePool(tokenIn, tokenOut, fee, pId).swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                abi.encodePacked(tokenIn, fee, pId, tokenOut)
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    function quoteExactInputSingle_iZi(
        // no pool identifier
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint128 amount
    ) public returns (uint256 amountOut) {
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try
                getiZiPool(tokenOut, tokenIn, fee).swapX2Y(
                    address(this), // address(0) might cause issues with some tokens
                    amount,
                    boundaryPoint,
                    abi.encodePacked(tokenIn, fee, uint8(0), tokenOut)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try
                getiZiPool(tokenOut, tokenIn, fee).swapY2X(
                    address(this), // address(0) might cause issues with some tokens
                    amount,
                    boundaryPoint,
                    abi.encodePacked(tokenIn, fee, uint8(0), tokenOut)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }

    function quoteExactInputV3(bytes calldata path, uint256 amountIn) external returns (uint256 amountOut) {
        while (true) {
            bool hasMultiplePools = path.length > 20 + 20 + 3 + 1;

            address tokenIn;
            address tokenOut;
            uint24 fee;
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset) // load first 32 bytes
                tokenIn := shr(96, firstWord) // right shift by 12 yields first token
                fee := and(shr(72, firstWord), 0xffffff) // right shft by 9 (=12-3) bytes is the fee
                poolId := shr(64, firstWord) // right shift by 8 = (9 - 1) bytes
                tokenOut := shr(96, calldataload(add(path.offset, 24))) // tokenOut starts at 24th byte
            }
            // the outputs of prior swaps become the inputs to subsequent ones
            amountIn = quoteExactInputSingleV3(tokenIn, tokenOut, fee, poolId, amountIn);
            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path[24:];
            } else {
                return amountIn;
            }
        }
    }

    function quoteExactOutputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint8 poolId,
        uint256 amountOut
    ) public returns (uint256 amountIn) {
        bool zeroForOne = tokenIn < tokenOut;

        // if no price limit has been specified, cache the output amount for comparison in the swap callback
        amountOutCached = amountOut;
        try
            v3TypePool(tokenIn, tokenOut, fee, poolId).swap(
                address(this), // address(0) might cause issues with some tokens
                zeroForOne,
                -int256(amountOut),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                abi.encodePacked(tokenOut, fee, poolId, tokenIn)
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
        uint24 fee,
        uint128 desire
    ) public returns (uint256 amountIn) {
        amountOutCached = desire;
        if (tokenIn < tokenOut) {
            int24 boundaryPoint = -799999;
            try
                getiZiPool(tokenOut, tokenIn, fee).swapX2YDesireY(
                    address(this), // address(0) might cause issues with some tokens
                    desire + 1,
                    boundaryPoint,
                    abi.encodePacked(tokenOut, fee, uint8(0), tokenIn)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        } else {
            int24 boundaryPoint = 799999;
            try
                getiZiPool(tokenOut, tokenIn, fee).swapY2XDesireX(
                    address(this), // address(0) might cause issues with some tokens
                    desire + 1,
                    boundaryPoint,
                    abi.encodePacked(tokenOut, fee, uint8(0), tokenIn)
                )
            {} catch (bytes memory reason) {
                return parseRevertReason(reason);
            }
        }
    }

    function quoteExactOutputV3(bytes calldata path, uint256 amountOut) external returns (uint256 amountIn) {
        while (true) {
            bool hasMultiplePools = path.length > 20 + 20 + 3 + 1;

            address tokenIn;
            address tokenOut;
            uint24 fee;
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord) // in exact out case, tokens are switched
                poolId := shr(64, firstWord) // poolId and fee are still in the same order
                fee := and(shr(72, firstWord), 0xffffff)
                tokenIn := shr(96, calldataload(add(path.offset, 24)))
            }
            // the inputs of prior swaps become the outputs of subsequent ones
            amountOut = quoteExactOutputSingleV3(tokenIn, tokenOut, fee, poolId, amountOut);

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path[24:];
            } else {
                return amountOut;
            }
        }
    }

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint8 pId) private pure returns (ISwapPool pool) {
        uint256 _pId = pId;
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // FusionX
            case 0 {
                mstore(p, FUSION_V3_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, FUSION_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Agni
            case 1 {
                mstore(p, AGNI_V3_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, AGNI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Swapsicle
            case 2 {
                mstore(p, ALGEBRA_V3_FF_DEPLOYER)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(p, keccak256(p, 64))
                p := add(p, 32)
                mstore(p, ALGEBRA_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Butter
            default {
                mstore(p, BUTTER_FF_FACTORY)
                p := add(p, 21)
                // Compute the inner hash in-place
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(p, tokenB)
                    mstore(add(p, 32), tokenA)
                }
                default {
                    mstore(p, tokenA)
                    mstore(add(p, 32), tokenB)
                }
                mstore(add(p, 64), and(UINT24_MASK, fee))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, BUTTER_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
        }
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getiZiPool(address tokenA, address tokenB, uint24 fee) private pure returns (IiZiSwapPool pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            mstore(p, IZI_FF_FACTORY)
            p := add(p, 21)
            switch lt(tokenA, tokenB)
            case 0 {
                mstore(p, tokenB)
                mstore(add(p, 32), tokenA)
            }
            default {
                mstore(p, tokenA)
                mstore(add(p, 32), tokenB)
            }
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, IZI_POOL_INIT_CODE_HASH)
            pool := and(ADDRESS_MASK, keccak256(s, 85))
        }
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function v2TypePairAddress(address tokenA, address tokenB, uint8) private pure returns (address pair) {
        assembly {
            switch lt(tokenA, tokenB)
            case 0 {
                mstore(0xB14, tokenA)
                mstore(0xB00, tokenB)
            }
            default {
                mstore(0xB14, tokenB)
                mstore(0xB00, tokenA)
            }
            let salt := keccak256(0xB0C, 0x28)

            // FusionX
            mstore(0xB00, FUSION_V2_FF_FACTORY)
            mstore(0xB15, salt)
            mstore(0xB35, CODE_HASH_FUSION_V2)

            pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
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
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord) // get first token
                poolId := shr(64, firstWord) // right shift by 8 bytes ends in byte 24 from the left
                tokenOut := shr(96, calldataload(add(path.offset, 24))) // tokenOut starts at 24th byte
            }

            // v3
            if (poolId < 50) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountIn = quoteExactInputSingleV3(tokenIn, tokenOut, fee, poolId, amountIn);
            }
            // V2
            else if (poolId < 100) {
                address pair = v2TypePairAddress(tokenIn, tokenOut, poolId);
                amountIn = getV2AmountOutDirect(pair, tokenIn < tokenOut, amountIn);
            }
            // iZi
            else if (poolId == 100) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountIn = quoteExactInputSingle_iZi(tokenIn, tokenOut, fee, uint128(amountIn));
            }

            /// decide whether to continue or terminate
            if (path.length > 20 + 20 + 4) {
                path = path[24:];
            } else {
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
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord) // get first token
                poolId := shr(64, firstWord) // right shift by 8 bytes ends in byte 24 from the left
                tokenIn := shr(96, calldataload(add(path.offset, 24))) // tokenOut starts at 24th byte
            }

            // v3
            if (poolId < 50) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountOut = quoteExactOutputSingleV3(tokenIn, tokenOut, fee, poolId, amountOut);
            }
            // V2
            else if (poolId < 100) {
                address pair = v2TypePairAddress(tokenIn, tokenOut, poolId);
                amountOut = getV2AmountInDirect(pair, tokenOut < tokenIn, amountOut);
            } else if (poolId == 100) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountOut = quoteExactOutputSingle_iZi(tokenIn, tokenOut, fee, uint128(amountOut));
            }
            /// decide whether to continue or terminate
            if (path.length > 20 + 20 + 4) {
                path = path[24:];
            } else {
                return amountOut;
            }
        }
    }

    function getV2AmountOutDirect(address pair, bool zeroForOne, uint256 sellAmount) private view returns (uint256 buyAmount) {
        assembly {
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

            // Compute the buy amount based on the pair reserves.
            {
                let sellReserve
                let buyReserve
                switch iszero(zeroForOne)
                case 0 {
                    // Transpose if pair order is different.
                    sellReserve := mload(0xC00)
                    buyReserve := mload(0xC20)
                }
                default {
                    sellReserve := mload(0xC20)
                    buyReserve := mload(0xC00)
                }
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * 998 * buyReserve) /
                //     (pairSellAmount * 998 + sellReserve * 1000);
                let sellAmountWithFee := mul(sellAmount, 998)
                buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
            }
        }
    }

    /// @dev calculates the input amount for a UniswapV2 style swap
    function getV2AmountInDirect(address pair, bool zeroForOne, uint256 buyAmount) private view returns (uint256 sellAmount) {
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
                let sellReserve
                let buyReserve
                switch iszero(zeroForOne)
                case 0 {
                    // Transpose if pair order is different.
                    sellReserve := mload(add(ptr, 0x20))
                    buyReserve := mload(ptr)
                }
                default {
                    sellReserve := mload(ptr)
                    buyReserve := mload(add(ptr, 0x20))
                }
                // if the buy amount is higher than the reserve, revert.
                if lt(buyReserve, buyAmount) {
                    revert(0, 0)
                }
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // sellAmount = (reserveIn * amountOut * 1000) /
                //     ((reserveOut - amountOut) * 998) + 1;
                sellAmount := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 998)), 1)
            }
        }
    }
}
