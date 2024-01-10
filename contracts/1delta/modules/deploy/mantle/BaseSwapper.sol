// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {IUniswapV3Pool} from "../../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {IUniversalV3StyleSwap} from "../../../dex-tools/interfaces/IUniversalSwap.sol";
import {IUniswapV2Pair} from "../../../../external-protocols/uniswapV2/core/interfaces/IUniswapV2Pair.sol";
import {TokenTransfer} from "../../../libraries/TokenTransfer.sol";
// solhint-disable max-line-length

/**
 * @title Uniswap Callback Base contract
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

    address private constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    constructor() {}

    function getLastToken(bytes calldata data) internal pure returns (address token) {
        assembly {
            token := shr(96, calldataload(add(data.offset, sub(data.length, 21))))
        }
    }

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getUniswapV3Pool(address tokenA, address tokenB, uint24 fee, uint8 pId) internal pure returns (IUniversalV3StyleSwap pool) {
        uint256 _pId = pId;
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
    function pairAddress(address tokenA, address tokenB, uint8 pId) internal view returns (address pair) {
        uint256 _pId = pId;
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
            default {
                // selector for getPair(address,address
                mstore(0xB00, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                mstore(add(0xB00, 0x4), tokenA)
                mstore(add(0xB00, 0x24), tokenB)

                // call to collateralToken
                pop(staticcall(gas(), MERCHANT_MOE_FACTORY, 0xB00, 0x48, 0xB00, 0x20))

                // load the retrieved protocol share
                pair := and(ADDRESS_MASK, mload(0xB00))
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
                assembly {
                    fee := and(shr(72, calldataload(path.offset)), 0xffffff)
                }
                bool zeroForOne = tokenIn < tokenOut;
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
            // decide whether to continue or terminate
            if (path.length > 46) {
                path = path[25:];
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }

    /// @dev simple exact input swap using uniswapV2 or fork
    function swapUniV2ExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint8 pId // we need to know the DEX for the fee
    ) private returns (uint256 buyAmount) {
        uint256 _pId = pId;
        assembly {
            let zeroForOne := lt(tokenIn, tokenOut)
            let pair := mload(0x40) // use free memo for pair
            switch _pId
            case 50 {
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
            default {
                // selector for getPair(address,address
                mstore(0xB00, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                mstore(add(0xB00, 0x4), tokenIn)
                mstore(add(0xB00, 0x24), tokenOut)

                // call to collateralToken
                pop(staticcall(gas(), MERCHANT_MOE_FACTORY, 0xB00, 0x48, 0xB00, 0x20))

                // load the retrieved protocol share
                pair := and(ADDRESS_MASK, mload(0xB00))
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
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch _pId
                case 50 {
                    // feeAm is 998 for fusionX (1000 - 2) for 0.2% fee
                    let sellAmountWithFee := mul(amountIn, 998)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                default {
                    // feeAm is 997 for Moe (1000 - 3) for 0.3% fee
                    let sellAmountWithFee := mul(amountIn, 997)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
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
                    100, // input size = 164 (selector (4bytes) plus 5*32bytes)
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
        bool zeroForOne,
        uint256 buyAmount,
        uint8 pId // required to apply the correct fee
    ) internal view returns (uint256 sellAmount) {
        uint256 _pId = pId;
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

                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // sellAmount = (reserveIn * amountOut * 1000) /
                //     ((reserveOut - amountOut) * feeAm) + 1;
                switch _pId
                case 50 {
                    // feeAm is 998 for fusionX
                    sellAmount := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 998)), 1)
                }
                default {
                    // feAm is 997 for Moe
                    sellAmount := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 997)), 1)
                }
            }
        }
    }
}
