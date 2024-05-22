// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {V3TypeSwapper} from "./V3Type.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract UniTypeSwapper is V3TypeSwapper {
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    /// @dev used for some of the denominators in solidly calculations
    uint256 private constant SCALE_18 = 1.0e18;

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;
    address internal constant CLEO_V1_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;
    address internal constant STRATUM_FACTORY = 0x061FFE84B0F9E1669A6bf24548E5390DBf1e03b2;

    constructor() {}

    /// @dev Compute or fetch a UniV2 or Solidly style pair address and validate that this is the caller
    function validateV2PairAddress(address tokenA, address tokenB, uint256 _pId) internal view {
        assembly {
            let pair
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

            if iszero(eq(pair, caller())) {
                revert (0, 0)
            }
        }
    }

    /// @dev Swap exact out via v2 type pool
    function _swapV2StyleExactOut(
        uint256 amountOut,
        address receiver,
        bytes calldata path
    )
        internal
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            let pair
            let firstWord := calldataload(path.offset)
            let tokenB := shr(96, firstWord)
            let _pId := and(shr(64, firstWord), UINT8_MASK)
            let tokenA := shr(96, calldataload(add(path.offset, 25)))
            let zeroForOne := lt(tokenA, tokenB)

            ////////////////////////////////////////////////////
            // Same code as for the other V2 pool address getters
            ////////////////////////////////////////////////////
            switch _pId
            // FusionX
            case 50 {
                switch zeroForOne
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
                // selector for getPair(address,address)
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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

            // selector for swap(...)
            mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)

            switch zeroForOne
            case 1 {
                mstore(add(ptr, 4), 0x0)
                mstore(add(ptr, 36), amountOut)
            }
            default {
                mstore(add(ptr, 4), amountOut)
                mstore(add(ptr, 36), 0x0)
            }
            // Prepare external call data

            // Store sqrtPriceLimitX96
            mstore(add(ptr, 68), address())
            // Store data offset
            mstore(add(ptr, 100), sub(0xa0, 0x20))
            /// Store data length
            mstore(add(ptr, 132), path.length)
            // Store path
            calldatacopy(add(ptr, 164), path.offset, path.length)
            // Perform the external 'swap' call
            if iszero(call(gas(), pair, 0, ptr, add(196, path.length), ptr, 0x0)) {
                // store return value directly to free memory pointer
                // The call failed; we retrieve the exact error message and revert with it
                returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                revert(0, returndatasize()) // Revert with the error message
            }

            ////////////////////////////////////////////////////
            // We chain the transfer to the receiver, given that
            // it is not this address
            ////////////////////////////////////////////////////
            if iszero(eq(address(), receiver)) {
                ////////////////////////////////////////////////////
                // Populate tx for transfer to receiver
                ////////////////////////////////////////////////////
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)

                let success := call(gas(), tokenB, 0, ptr, 0x44, ptr, 32)

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
                    returndatacopy(0x0, 0, rdsize)
                    revert(0x0, rdsize)
                }
            }
        }
    }

    /**
     * Calculates the input amount for a UniswapV2 and Solidly style swap
     * Assumes that the pair address has been pre-calculated
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
                            _reserveInScaled := div(mul(mload(ptr), SCALE_18), _decimalsIn)
                            _reserveOutScaled := div(mul(mload(add(ptr, 0x20)), SCALE_18), _decimalsOut_xy_fee)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(add(ptr, 0x20)), SCALE_18), _decimalsIn)
                            _reserveOutScaled := div(mul(mload(ptr), SCALE_18), _decimalsOut_xy_fee)
                        }
                        y0 := sub(_reserveOutScaled, div(mul(buyAmount, SCALE_18), _decimalsOut_xy_fee))
                        x := _reserveInScaled
                        // get xy
                        _decimalsOut_xy_fee := div(
                            mul(
                                div(mul(_reserveInScaled, _reserveOutScaled), SCALE_18),
                                add(
                                    div(mul(_reserveInScaled, _reserveInScaled), SCALE_18),
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
                        switch lt(k, _decimalsOut_xy_fee)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy_fee, k), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
                                        div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)
                                    )
                                )
                            )
                        }
                        default {
                            x := sub(
                                x,
                                div(
                                    mul(sub(k, _decimalsOut_xy_fee), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
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
                            SCALE_18
                        ),
                        1 // rounding up
                    )
                }
            }
        }
    }

    /**
     * Executes an exact input swap internally across major UniV2 & Solidly style forks
     * Due to the nature of the V2 impleemntation, the callback is not triggered if no calldata is provided
     * As such, we never enter the callback implementation when using this function
     * @param amountIn sell amount
     * @param useFlashSwap if set to true, the amount in will not be transferred and a
     *                     payback is expected to be done in the callback
     * @return buyAmount output amount
     */
    function swapUniV2ExactInComplete(
        uint256 amountIn,
        bool useFlashSwap,
        bytes calldata path
    ) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair
            let success
            let firstWord := calldataload(path.offset)
            let tokenIn := shr(96, firstWord)
            let tokenOut := shr(96, calldataload(add(path.offset, UNI3_TOKEN_OUT_OFFSET)))
            let zeroForOne := lt(tokenIn, tokenOut)
            let pool := shr(96, calldataload(add(path.offset, UNI3_POOL_OFFSET)))
            let _pId := and(shr(80, firstWord), UINT8_MASK) // poolId
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

                ////////////////////////////////////////////////////
                // Prepare the swap tx
                ////////////////////////////////////////////////////

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
                mstore(0xB64, 0x80) // bytes offset

                ////////////////////////////////////////////////////
                // In case of a flash swap, we copy the calldata to
                // the execution parameters
                ////////////////////////////////////////////////////
                switch useFlashSwap
                case 1 {
                    mstore(0xB84, path.length) // bytes length
                    calldatacopy(0xBA4, path.offset, path.length)
                    success := call(
                        gas(),
                        pair,
                        0x0,
                        0xB00, // input selector
                        add(0xA4, path.length), // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0x0, // output = 0
                        0x0 // output size = 0
                    )
                }
                ////////////////////////////////////////////////////
                // Otherwise, we transfer before
                ////////////////////////////////////////////////////
                default {
                    ////////////////////////////////////////////////////
                    // Populate tx for transfer to pair
                    ////////////////////////////////////////////////////
                    // selector for transfer(address,uint256)
                    mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), and(pair, ADDRESS_MASK_UPPER))
                    mstore(add(ptr, 0x24), amountIn)

                    success := call(gas(), and(tokenIn, ADDRESS_MASK_UPPER), 0, ptr, 0x44, ptr, 32)

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
                        returndatacopy(0x0, 0, rdsize)
                        revert(0x0, rdsize)
                    }

                    ////////////////////////////////////////////////////
                    // We store the bytes length to zero (no callback)
                    // and directly trigger the swap
                    ////////////////////////////////////////////////////
                    mstore(0xB84, 0) // bytes length
                    success := call(
                        gas(),
                        pair,
                        0x0,
                        0xB00, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )
                }
 
                if iszero(success) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }


}
