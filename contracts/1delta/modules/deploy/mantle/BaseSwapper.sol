// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {IUniversalV3StyleSwap} from "../../../dex-tools/interfaces/IUniversalSwap.sol";
import {IUniswapV2Pair} from "../../../../external-protocols/uniswapV2/core/interfaces/IUniswapV2Pair.sol";
import {TokenTransfer} from "../../../libraries/TokenTransfer.sol";

// solhint-disable max-line-length

/**
 * @title Any Uniswap Callback Base contract
 * @notice Contains main logic for uniswap callbacks
 */
abstract contract BaseSwapper is TokenTransfer {
    /// @dev Mask of lower 20 bytes.
    uint256 private constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 private constant UINT24_MASK = 0xffffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

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

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;
    address internal constant CLEO_V1_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;
    address internal constant STRATUM_FACTORY = 0x061FFE84B0F9E1669A6bf24548E5390DBf1e03b2;

    address private constant WOO_POOL = 0x9D1A92e601db0901e69bd810029F2C14bCCA3128;
    address internal constant REBATE_RECIPIENT = 0xC95eED7F6E8334611765F84CEb8ED6270F08907E;

    address internal constant STRATUM_3POOL = 0xD6F312AA90Ad4C92224436a7A4a648d69482e47e;
    address internal constant MUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;
    address internal constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;

    constructor() {}

    function getLastToken(bytes calldata data) internal pure returns (address token) {
        assembly {
            token := shr(96, calldataload(add(data.offset, sub(data.length, 21))))
        }
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getUniswapV3Pool(address tokenA, address tokenB, uint24 fee, uint256 _pId) internal pure returns (IUniversalV3StyleSwap pool) {
        assembly {
            let s := mload(0x40)
            let p := s
            switch _pId
            // Fusion
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
            // agni
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
            case 4 {
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
            // iZi
            default {
                mstore(p, IZI_FF_FACTORY)
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
                mstore(p, IZI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
        }
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function pairAddress(address tokenA, address tokenB, uint256 _pId) internal view returns (address pair) {
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

    /// @dev swaps exact input through UniswapV3 or UniswapV2 style exactIn
    /// only uniswapV3 executes flashSwaps
    function swapExactIn(uint256 amountIn, bytes calldata path) internal returns (uint256 amountOut) {
        while (true) {
            address tokenIn;
            address tokenOut;
            uint8 identifier;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenIn := shr(96, firstWord)
                identifier := shr(64, firstWord)
                tokenOut := shr(96, calldataload(add(path.offset, 25)))
            }
            // uniswapV3 style
            if (identifier < 50) {
                uint24 fee;
                bool zeroForOne;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                    zeroForOne := lt(tokenIn, tokenOut)
                }
                (int256 amount0, int256 amount1) = getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swap(
                    address(this),
                    zeroForOne,
                    int256(amountIn),
                    zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                    path[:45]
                );

                amountIn = uint256(-(zeroForOne ? amount1 : amount0));
            }
            // uniswapV2 style
            else if (identifier < 100) {
                amountIn = swapUniV2ExactIn(tokenIn, tokenOut, amountIn, identifier);
            }
            // iZi
            else if (identifier == 100) {
                uint24 fee;
                bool zeroForOne;
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                    zeroForOne := lt(tokenIn, tokenOut)
                }
                if (zeroForOne)
                    (, amountIn) = getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2Y(
                        address(this),
                        uint128(amountIn),
                        -799999, // low tick
                        path
                    );
                else
                    (amountIn, ) = getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2X(
                        address(this),
                        uint128(amountIn),
                        799999, // high tick
                        path
                    );
            }
            // WOO Fi
            else if (identifier == 101) {
                amountIn = swapWooFiExactIn(tokenIn, tokenOut, amountIn);
            }
            // Stratum 3USD
            else if (identifier == 102) {
                amountIn = swapStratum3(tokenIn, tokenOut, amountIn);
            }
            // decide whether to continue or terminate
            if (path.length > 46) {
                path = path[25:];
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }

    function swapWooFiExactIn(address tokenIn, address tokenOut, uint256 amountIn) private returns (uint256 amountOut) {
        assembly {
            // selector for transfer(address,uint256)
            mstore(0xB00, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(0xB00, 0x04), WOO_POOL)
            mstore(add(0xB00, 0x24), amountIn)

            let success := call(gas(), tokenIn, 0, 0xB00, 0x44, 0xB00, 32)

            let rdsize := returndatasize()

            // Check for ERC20 success. ERC20 tokens should return a boolean,
            // but some don't. We accept 0-length return data as success, or at
            // least 32 bytes that starts with a 32-byte boolean true.
            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(0xB00), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(0xB00, 0, rdsize)
                revert(0xB00, rdsize)
            }
            // selector for swap(address,address,uint256,uint256,address,address)
            mstore(
                0xB00, // 2816
                0x7dc2038200000000000000000000000000000000000000000000000000000000
            )
            mstore(0xB04, tokenIn)
            mstore(0xB24, tokenOut)
            mstore(0xB44, amountIn)
            mstore(0xB64, 0x0) // amountOutMin unused
            mstore(0xB84, address()) // recipient
            mstore(0xBA4, REBATE_RECIPIENT) // rebateTo
            success := call(
                gas(),
                WOO_POOL,
                0x0, // no native transfer
                0xB00,
                0xC4, // input length 196
                0xB00, // store output here
                0x20 // output is just uint
            )
            if iszero(success) {
                rdsize := returndatasize()
                returndatacopy(0xB00, 0, rdsize)
                revert(0xB00, rdsize)
            }

            amountOut := mload(0xB00)
        }
    }

    function swapStratum3(address tokenIn, address tokenOut, uint256 amountIn) private returns (uint256 amountOut) {
        assembly {
            let indexIn
            let indexOut
            switch tokenIn
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {
                // execute USDY->mUSD wrap
                // selector for wrap(uint256)
                mstore(0xB00, 0xea598cb000000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, amountIn)
                if iszero(call(gas(), MUSD, 0x0, 0xB00, 0x24, 0xB00, 0x0)) {
                    let rdsize := returndatasize()
                    returndatacopy(0xB00, 0, rdsize)
                    revert(0xB00, rdsize)
                }
                // selector for balanceOf(address)
                mstore(0xB00, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                // add this address as parameter
                mstore(0xB04, address())
                // call to token
                pop(staticcall(gas(), MUSD, 0xB00, 0x24, 0xB00, 0x20))

                // load the retrieved balance
                amountIn := mload(0xB00)
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
            // selector for swap(uint8,uint8,uint256,uint256,uint256)
            mstore(0xB00, 0x9169558600000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            mstore(0xB64, 0) // min out is zero, we validate slippage at the end
            mstore(0xB84, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // no deadline
            if iszero(call(gas(), STRATUM_3POOL, 0x0, 0xB00, 0xA4, 0xB00, 0x20)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0, rdsize)
                revert(0xB00, rdsize)
            }

            amountOut := mload(0xB00)

            if eq(tokenOut, USDY) {
                // calculate mUSD->USDY unwrap
                // selector for unwrap(uint256)
                mstore(0xB00, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, amountOut)
                if iszero(call(gas(), MUSD, 0x0, 0xB00, 0x24, 0xB00, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0xB00, 0, rdsize)
                    revert(0xB00, rdsize)
                }
                // selector for balanceOf(address)
                mstore(0xB00, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                // add this address as parameter
                mstore(add(0xB00, 0x4), address())
                // call to token
                pop(staticcall(5000, USDY, 0xB00, 0x24, 0xB00, 0x20))
                // load the retrieved balance
                amountOut := mload(0xB00)
            }
        }
    }

    /// @dev simple exact input swap using uniswapV2 or fork
    function swapUniV2ExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 _pId // we need to know the DEX for the fee
    ) private returns (uint256 buyAmount) {
        assembly {
            let zeroForOne := lt(tokenIn, tokenOut)
            let pair := mload(0x40) // use free memo for pair
            switch _pId
            case 50 {
                // fusionX
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, FUSION_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_FUSION_V2)

                pair := and(ADDRESS_MASK_UPPER, keccak256(0xB00, 0x55))
            }
            case 51 {
                // merchant moe -> call to factory to identify pair address
                // selector for getPair(address,address)
                mstore(0xB00, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                mstore(add(0xB00, 0x4), tokenIn)
                mstore(add(0xB00, 0x24), tokenOut)

                // call to factory
                pop(staticcall(gas(), MERCHANT_MOE_FACTORY, 0xB00, 0x48, 0xB00, 0x20))
                // load the retrieved protocol share
                pair := and(ADDRESS_MASK, mload(0xB00))
            }
            // Velo Volatile
            case 52 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
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
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
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
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
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
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
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
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
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
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, STRATUM_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // EXECUTE TRANSFER TO PAIR
            let ptr := mload(0x40) // free memory pointer
            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(pair, ADDRESS_MASK_UPPER))
            mstore(add(ptr, 0x24), amountIn)

            let success := call(gas(), and(tokenIn, ADDRESS_MASK_UPPER), 0, ptr, 0x44, ptr, 32)

            let rdsize := returndatasize()

            // Check for ERC20 success. ERC20 tokens should return a boolean,
            // but some don't. We accept 0-length return data as success, or at
            // least 32 bytes that starts with a 32-byte boolean true.
            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(ptr), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
            // TRANSFER COMPLETE

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
                    switch zeroForOne
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // feeAm is 998 for fusionX (1000 - 2) for 0.2% fee
                    let sellAmountWithFee := mul(amountIn, 998)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
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
                    switch zeroForOne
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // feeAm is 997 for Moe (1000 - 3) for 0.3% fee
                    let sellAmountWithFee := mul(amountIn, 997)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                // all solidly-based protocols (velo, cleo V1, stratum)
                default {
                    // selector for getAmountOut(uint256,address)
                    mstore(0xB00, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(0xB04, amountIn)
                    mstore(0xB24, tokenIn)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x44, 0xB00, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    buyAmount := mload(0xB00)
                }
                // selector for swap(...)
                mstore(0xB00, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)

                switch zeroForOne
                case 0 {
                    mstore(0xB04, buyAmount)
                    mstore(0xB24, 0)
                }
                default {
                    mstore(0xB04, 0)
                    mstore(0xB24, buyAmount)
                }
                mstore(0xB44, address())
                mstore(0xB64, 0x80) // bytes classifier
                mstore(0xB84, 0) // bytesdata

                success := call(
                    gas(),
                    pair,
                    0x0,
                    0xB00, // input selector
                    0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                    0, // output = 0
                    0 // output size = 0
                )
                if iszero(success) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }

    /// @dev calculates the input amount for a UniswapV2 style swap
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
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(add(ptr, 0x20))
                        buyReserve := mload(ptr)
                    }
                    default {
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feeAm is 998 for fusionX
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 998)), 1)
                }
                // merchant moe
                case 51 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(add(ptr, 0x20))
                        buyReserve := mload(ptr)
                    }
                    default {
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feAm is 997 for Moe
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 997)), 1)
                }
                // velo volatile
                case 52 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(add(ptr, 0x20))
                        buyReserve := mload(ptr)
                    }
                    default {
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
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
                // stratum volatile
                case 56 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(add(ptr, 0x20))
                        buyReserve := mload(ptr)
                    }
                    default {
                        sellReserve := mload(ptr)
                        buyReserve := mload(add(ptr, 0x20))
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
                // cleo V1 volatile
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
                    let _decimalsOut_xy_fee
                    let y0
                    let _reserveInScaled
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
                            _reserveOutScaled := div(mul(mload(add(ptr, 0x20)), 1000000000000000000), _decimalsOut_xy_fee)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(add(ptr, 0x20)), 1000000000000000000), _decimalsIn)
                            _reserveOutScaled := div(mul(mload(ptr), 1000000000000000000), _decimalsOut_xy_fee)
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
                    // selector for getFee(address)
                    switch pId
                    // velo stable
                    case 53 {
                        mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x4), pair)
                        pop(staticcall(gas(), VELO_FACTORY, ptr, 0x24, ptr, 0x20))
                        _decimalsOut_xy_fee := mload(ptr)
                    }
                    // stratum stable
                    case 57 {
                        mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x4), pair)
                        pop(staticcall(gas(), STRATUM_FACTORY, ptr, 0x24, ptr, 0x20))
                        _decimalsOut_xy_fee := mload(ptr)
                    }
                    // cleo stable
                    default {
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
