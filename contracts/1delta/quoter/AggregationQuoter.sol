// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

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

/**
 * Quoter contract
 * Paths have to be encoded as follows: token0 (address) | param0 (uint24) | poolId (uint8) | token1 (address) |
 */
contract OneDeltaQuoter {
    error tickOutOfRange();
    /// @dev Transient storage variable used to check a safety condition in exact output swaps.
    uint256 private amountOutCached;

    /// @dev Mask of lower 20 bytes.
    uint256 private constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 private constant UINT24_MASK = 0xffffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // _FF_ is given as follows: bytes32((uint256(0xff) << 248) | (uint256(uint160(address)) << 88));

    bytes32 private constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 private constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant RETRO_FF_FACTORY = 0xff91e1B99072f238352f59e58de875691e20Dc19c10000000000000000000000;
    bytes32 private constant RETRO_POOL_INIT_CODE_HASH = 0x817e07951f93017a93327ac8cc31e946540203a19e1ecc37bc1761965c2d1090;

    bytes32 private constant ALGEBRA_V3_FF_DEPLOYER = 0xff2d98e2fa9da15aa6dc9581ab097ced7af697cb920000000000000000000000;
    bytes32 private constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    bytes32 private constant SUSHI_V3_FF_DEPLOYER = 0xff917933899c6a5F8E37F31E19f92CdBFF7e8FF0e20000000000000000000000;
    bytes32 private constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 private constant QUICK_V2_FF_FACTORY = 0xff5757371414417b8c6caad45baef941abc7d3ab320000000000000000000000;
    bytes32 private constant CODE_HASH_QUICK_V2 = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant SUSHI_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 private constant CODE_HASH_SUSHI_V2 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;
 
    bytes32 private constant DFYN_FF_FACTORY = 0xffE7Fb3e833eFE5F9c441105EB65Ef8b261266423B0000000000000000000000;
    bytes32 private constant CODE_HASH_DFYN = 0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3;

    constructor() {}

    // uniswap V3 type callback
    function _v3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) private view {
        // we do not validate the callback since it's just a pure function
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
            if (amountOutCached != 0) require(amountReceived == amountOutCached);
            assembly {
                let ptr := mload(0x40)
                mstore(ptr, amountToPay)
                revert(ptr, 32)
            }
        }
    }

    // quickswap
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

     // uniswap & sushiswap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external view {
        _v3SwapCallback(amount0Delta, amount1Delta, path);
    }

    /// @dev Parses a revert reason that should contain the numeric quote
    function parseRevertReason(bytes memory reason) private pure returns (uint256) {
        if (reason.length != 32) {
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256));
    }

    function quoteExactInputSingleV3(
        address tokenIn, 
        address tokenOut,
        uint24 fee, 
        uint8 pId,
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
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint8 pId) internal pure returns (ISwapPool pool) {
        uint256 _pId = pId;
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // Uni
            case 0 {
                mstore(p, UNI_V3_FF_FACTORY)
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
                mstore(p, UNI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Quickswap
            case 1 {
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
            // Sushiswap V3
            case 2 {
                mstore(p, SUSHI_V3_FF_DEPLOYER)
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
                mstore(p, SUSHI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Retro
            default {
                mstore(p, RETRO_FF_FACTORY)
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
                mstore(p, RETRO_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
        }
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function v2TypePairAddress(address tokenA, address tokenB, uint8 pId) internal pure returns (address pair) {
        uint256 _pId = pId;
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
            switch _pId
            case 50 {
                // Quickswap
                mstore(0xB00, QUICK_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_QUICK_V2)
            }
            case 51 {
                // Sushiswap
                mstore(0xB00, SUSHI_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_SUSHI_V2)
            }
            default {
                // dfyn
                mstore(0xB00, DFYN_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_DFYN)
            }
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
                // buyAmount = (pairSellAmount * 997 * buyReserve) /
                //     (pairSellAmount * 997 + sellReserve * 1000);
                let sellAmountWithFee := mul(sellAmount, 997)
                buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
            }
        }
    }

    /// @dev calculates the input amount for a UniswapV2 style swap
    function getV2AmountInDirect(address pair, bool zeroForOne, uint256 buyAmount) internal view returns (uint256 sellAmount) {
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
                //     ((reserveOut - amountOut) * 997) + 1;
                sellAmount := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 997)), 1)
            }
        }
    }
}
