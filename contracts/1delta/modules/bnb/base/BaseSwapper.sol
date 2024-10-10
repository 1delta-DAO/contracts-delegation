// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.27;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

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

    bytes32 private constant PANCAKE_V3_FF_FACTORY = 0xff41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c90000000000000000000000;
    bytes32 private constant PANCAKE_POOL_INIT_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;

    bytes32 private constant BISWAPV3_FF_FACTORY = 0xff4d175F2cFe3e2215c1B55865B07787b751CEdD360000000000000000000000;
    bytes32 private constant BISWAPV3_POOL_INIT_CODE_HASH = 0xf3034e9d7a0088686a7f25c4f21bbc3aaef5c12a91c85768621e4d450abb1cb1;

    bytes32 private constant IZI_FF_FACTORY = 0xff93BB94a0d5269cb437A1F71FF3a77AB7538444220000000000000000000000;
    bytes32 private constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 private constant ALGEBRA_V3_FF_DEPLOYER = 0xffc89F69Baa3ff17a842AB2DE89E5Fc8a8e2cc73580000000000000000000000;
    bytes32 private constant ALGEBRA_POOL_INIT_CODE_HASH = 0xd61302e7691f3169f5ebeca3a0a4ab8f7f998c01e55ec944e62cfb1109fd2736;

    bytes32 private constant UNISWAP_FF_FACTORY = 0xffdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F70000000000000000000000;
    bytes32 private constant UNISWAP_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    // V2 types

    bytes32 private constant PANCAKE_V2_FF_FACTORY = 0xffcA143Ce32Fe78f1f7019d7d551a6402fC5350c730000000000000000000000;
    bytes32 private constant CODE_HASH_PANCAKE_V2 = 0x00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5;

    bytes32 private constant BISWAP_V2_FF_FACTORY = 0xff858E3312ed3A876947EA49d572A7C42DE08af7EE0000000000000000000000;
    bytes32 private constant CODE_HASH_BISWAP_V2 = 0xfea293c909d87cd4153593f077b76bb7e94340200f4ee84211ae8e4f9bd7ffdf;

    bytes32 private constant APESWAP_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 private constant CODE_HASH_APESWAP_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

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
            // Pancake
            case 0 {
                mstore(p, PANCAKE_V3_FF_FACTORY)
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
                mstore(p, PANCAKE_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Thena
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
            // uniswap V3
            case 2 {
                mstore(p, UNISWAP_FF_FACTORY)
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
                mstore(p, UNISWAP_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // biswap
            case 100 {
                mstore(p, BISWAPV3_FF_FACTORY)
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
                mstore(p, BISWAPV3_POOL_INIT_CODE_HASH)
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
    function pairAddress(address tokenA, address tokenB, uint8 pId) internal pure returns (address pair) {
        uint256 _pId = pId;
        assembly {
            switch _pId
            case 50 {
                // pancake
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
                mstore(0xB00, PANCAKE_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_PANCAKE_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            case 51 {
                // biswap
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
                mstore(0xB00, BISWAP_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_BISWAP_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            default {
                // apeswap
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
                mstore(0xB00, APESWAP_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_APESWAP_V2)

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
                    (, amountIn) = getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2Y(address(this), uint128(amountIn), -799999, path);
                else (amountIn, ) = getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2X(address(this), uint128(amountIn), 799999, path);
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
    function swapUniV2ExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint8 pId) private returns (uint256 buyAmount) {
        uint256 _pId = pId;
        assembly {
            let zeroForOne := lt(tokenIn, tokenOut)
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
            let feeAm  // 10000 - fee
            let pair
            switch _pId
            case 50 {
                feeAm := 9975
                mstore(0xB00, PANCAKE_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_PANCAKE_V2)
                pair := and(ADDRESS_MASK_UPPER, keccak256(0xB00, 0x55))
            }
            case 51 {
                mstore(0xB00, BISWAP_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_BISWAP_V2)
                pair := and(ADDRESS_MASK_UPPER, keccak256(0xB00, 0x55))
                // we have to get the fee from the pair
                mstore(
                    0xB00,
                    0x54cf2aeb00000000000000000000000000000000000000000000000000000000 // swapFee()
                )
                pop(
                    staticcall(
                        5000,
                        pair, // call to pair
                        0xB00,
                        0x4, // only selector
                        0xB00,
                        0x20 // 1 slot
                    )
                )

                // fee of biswap has too low denom
                feeAm := sub(10000, mul(mload(0xB00), 10))
            }
            default {
                feeAm := 9920
                mstore(0xB00, APESWAP_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_APESWAP_V2)
                pair := and(ADDRESS_MASK_UPPER, keccak256(0xB00, 0x55))
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
                //     (pairSellAmount * feeAm + sellReserve * 10000);
                let sellAmountWithFee := mul(amountIn, feeAm)
                buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 10000)))

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
    function getAmountInDirect(address pair, bool zeroForOne, uint256 buyAmount, uint8 pId) internal view returns (uint256 sellAmount) {
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
                let feeAm  // 10000 - fee
                switch _pId
                case 50 {
                    // pancake: const fee
                    feeAm := 9975
                }
                case 51 {
                    // biswap, fetch fee
                    // we have to get the fee from the pair
                    mstore(
                        ptr,
                        0x54cf2aeb00000000000000000000000000000000000000000000000000000000 // swapFee()
                    )
                    // we know that a pair has this field
                    pop(
                        staticcall(
                            5000,
                            pair, // call to pair
                            ptr,
                            0x4, // only selector
                            ptr,
                            0x20 // 1 slot
                        )
                    )
                    // fee of biswap has too low denom
                    feeAm := sub(10000, mul(mload(ptr), 10))
                }
                default {
                    // apeswap lower fee
                    feeAm := 9920
                }
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // sellAmount = (reserveIn * amountOut * 1000) /
                //     ((reserveOut - amountOut) * feeAm) + 1;
                sellAmount := add(div(mul(mul(sellReserve, buyAmount), 10000), mul(sub(buyReserve, buyAmount), feeAm)), 1)
            }
        }
    }
}
