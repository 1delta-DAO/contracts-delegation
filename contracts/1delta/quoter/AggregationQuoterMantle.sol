// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

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
    error invalidDexId();
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

    bytes32 private constant CLEO_FF_FACTORY = 0xffAAA32926fcE6bE95ea2c51cB4Fcb60836D320C420000000000000000000000;
    bytes32 private constant CLEO_POOL_INIT_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    address private constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    address private constant MERCHANT_MOE_LB_FACTORY = 0xa6630671775c4EA2743840F9A5016dCf2A104054;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;
    address internal constant CLEO_V1_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;
    address internal constant STRATUM_FACTORY = 0x061FFE84B0F9E1669A6bf24548E5390DBf1e03b2;

    address private constant WOO_ROUTER = 0xd14a997308F9e7514a8FEA835064D596CDCaa99E;

    address internal constant STRATUM_3POOL = 0xD6F312AA90Ad4C92224436a7A4a648d69482e47e;
    address internal constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;
    address internal constant MUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;

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
    ) private returns (uint256 amountOut) {
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
    ) private returns (uint256 amountOut) {
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

    function quoteExactOutputSingleV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint8 poolId,
        uint256 amountOut
    ) private returns (uint256 amountIn) {
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
    ) private returns (uint256 amountIn) {
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

    function getLBAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint16 binStep // identifies the exact pair address
    ) private view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // getLBPairInformation(address,address,uint256)
            mstore(ptr, 0x704037bd00000000000000000000000000000000000000000000000000000000)
            // this flag indicates whether tokenOut is tokenY
            // the tokens in the pair are ordered, as such, we call lt
            let swapForY := lt(tokenIn, tokenOut)
            // order tokens for call
            switch swapForY
            case 1 {
                mstore(add(ptr, 0x4), tokenIn)
                mstore(add(ptr, 0x24), tokenOut)
            }
            default {
                mstore(add(ptr, 0x4), tokenOut)
                mstore(add(ptr, 0x24), tokenIn)
            }
            mstore(add(ptr, 0x44), binStep)
            pop( // the call will always succeed due to immutable call target
                staticcall(
                    gas(),
                    MERCHANT_MOE_LB_FACTORY,
                    ptr,
                    0x64,
                    ptr,
                    0x40 // we only need 64 bits of the output
                )
            )
            // get the pair
            let pair := and(
                0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff, // mask address
                mload(add(ptr, 0x20)) // skip index
            )
            // pair must exist
            if iszero(pair) {
                revert(0, 0)
            }
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    ptr,
                    0x4,
                    ptr,
                    0x20
                )
            )
            // override swapForY
            swapForY := eq(tokenOut, mload(ptr)) 
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
            if gt(0, mload(ptr)) {
                revert(0, 0)
            }
        }
    }

    function getLBAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint16 binStep // this param identifies the pair
    ) private view returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)
            // getLBPairInformation(address,address,uint256)
            mstore(ptr, 0x704037bd00000000000000000000000000000000000000000000000000000000)
            // this flag indicates whether tokenOut is tokenY
            // the tokens in the pair are ordered, as such, we call lt
            let swapForY := gt(tokenIn, tokenOut)
            // order tokens for call
            switch swapForY
            case 0 {
                mstore(add(ptr, 0x4), tokenIn)
                mstore(add(ptr, 0x24), tokenOut)
            }
            default {
                mstore(add(ptr, 0x4), tokenOut)
                mstore(add(ptr, 0x24), tokenIn)
            }
            mstore(add(ptr, 0x44), binStep)
            pop(
                // the call will always succeed due to immutable call target
                staticcall(
                    gas(),
                    MERCHANT_MOE_LB_FACTORY,
                    ptr,
                    0x64,
                    ptr,
                    0x40 // we only need 64 bits of the output
                )
            )
            // get the pair
            let pair := and(
                0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff, // mask address
                mload(add(ptr, 0x20)) // skip index
            )
            // pair must exist
            if iszero(pair) {
                revert(0, 0)
            }
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    ptr,
                    0x4,
                    ptr,
                    0x20
                )
            )
            // override swapForY
            swapForY := eq(tokenOut, mload(ptr)) 
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
            if gt(0, mload(add(ptr, 0x20))) {
                revert(0, 0)
            }
        }
    }

    /// @dev Returns the pool for the given token pair and fee.
    /// The pool contract may or may not exist.
    function v3TypePool(address tokenA, address tokenB, uint24 fee, uint256 _pId) private pure returns (ISwapPool pool) {
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
            case 3 {
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
            // Cleo
            default {
                mstore(p, CLEO_FF_FACTORY)
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
                mstore(p, CLEO_POOL_INIT_CODE_HASH)
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
    function v2TypePairAddress(address tokenA, address tokenB, uint256 _pId) private view returns (address pair) {
        assembly {
            switch _pId
            // FusionX
            case 50 {
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
                mstore(0xB00, FUSION_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_FUSION_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 51: Merchant Moe
            case 51 {
                // selector for getPair(address,address
                mstore(0xB00, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                mstore(add(0xB00, 0x4), tokenA)
                mstore(add(0xB00, 0x24), tokenB)

                // call to collateralToken
                pop(staticcall(gas(), MERCHANT_MOE_FACTORY, 0xB00, 0x48, 0xB00, 0x20))

                // load the retrieved protocol share
                pair := and(ADDRESS_MASK, mload(0xB00))
            }
            // Velo Volatile
            case 52 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Velo Stable
            case 53 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Cleo V1 Volatile
            case 54 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, CLEO_V1_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Cleo V1 Stable
            case 55 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, CLEO_V1_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Stratum Volatile
            case 56 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, STRATUM_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 57: Stratum Stable
            default {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, STRATUM_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
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
            uint8 poolId;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord) // get first token
                poolId := shr(64, firstWord) // right shift by 8 bytes ends in byte 24 from the left
                tokenOut := shr(96, calldataload(add(path.offset, 24))) // tokenOut starts at 24th byte
            }

            // v3 types
            if (poolId < 50) {
                uint24 fee;
                assembly {
                    fee := and(
                        shr(
                            72, // 72 = 64 (= 256 - 192 (= address (160) + 32)) + 8 (equivalent of pId entry)
                            calldataload(path.offset)
                        ),
                        0xffffff
                    )
                }
                amountIn = quoteExactInputSingleV3(tokenIn, tokenOut, fee, poolId, amountIn);
            }
            // v2 types
            else if (poolId < 100) {
                address pair = v2TypePairAddress(tokenIn, tokenOut, poolId);
                amountIn = getAmountOutUniV2Type(pair, tokenIn, tokenOut, amountIn, poolId);
            }
            // iZi
            else if (poolId == 100) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountIn = quoteExactInputSingle_iZi(tokenIn, tokenOut, fee, uint128(amountIn));
            } else if (poolId == 101) {
                amountIn = quoteWOO(tokenIn, tokenOut, amountIn);
            } else if (poolId == 102) {
                amountIn = quoteStratum3(tokenIn, tokenOut, amountIn);
            } else if (poolId == 103) {
                uint24 bin;
                assembly {
                    bin := and(
                        shr(
                            72, // we just use the uint24 slot for the uint16 and convert after
                            calldataload(path.offset)
                        ),
                        0xffffff
                    )
                }
                amountIn = getLBAmountOut(tokenIn, tokenOut, amountIn, uint16(bin));
            } else {
                revert invalidDexId();
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

            // v3 types
            if (poolId < 50) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountOut = quoteExactOutputSingleV3(tokenIn, tokenOut, fee, poolId, amountOut);
            }
            // v2 types
            else if (poolId < 100) {
                address pair = v2TypePairAddress(tokenIn, tokenOut, poolId);
                amountOut = getV2AmountInDirect(pair, tokenIn, tokenOut, amountOut, poolId);
            } else if (poolId == 100) {
                uint24 fee;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                amountOut = quoteExactOutputSingle_iZi(tokenIn, tokenOut, fee, uint128(amountOut));
            } else if (poolId == 103) {
                uint24 bin;
                assembly {
                    bin := and(
                        shr(
                            72, // we just use the uint24 slot for the uint16 and convert after
                            calldataload(path.offset)
                        ),
                        0xffffff
                    )
                }
                amountOut = getLBAmountIn(tokenIn, tokenOut, amountOut, uint16(bin));
            } else {
                revert invalidDexId();
            }
            /// decide whether to continue or terminate
            if (path.length > 20 + 20 + 4) {
                path = path[24:];
            } else {
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
    ) private view returns (uint256 buyAmount) {
        assembly {
            // Compute the buy amount based on the pair reserves.
            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch _pId
                case 50 {
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
                case 51 {
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

    function quoteWOO(address tokenIn, address tokenOut, uint256 amountIn) private view returns (uint256 amountOut) {
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

    function quoteStratum3(address tokenIn, address tokenOut, uint256 amountIn) private view returns (uint256 amountOut) {
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
                case 50 {
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
                case 51 {
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
                case 52 {
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
                case 56 {
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
                case 54 {
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
                    case 55 {
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
                    case 53 {
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
