// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * @title Native Transfer contract -> chain dependent
 */
contract Native is ERC20Selectors, Masks, DeltaErrors {
    // wNative
    address internal constant WRAPPED_NATIVE = 0x4200000000000000000000000000000000000006;

    /*
     * | Offset | Length (bytes) | Description         |
     * |--------|----------------|---------------------|
     * | 0      | 16             | amount              |
     */
    function _wrap(uint256 currentOffset, uint256 amountOverride) internal virtual returns (uint256) {
        ////////////////////////////////////////////////////
        // Wrap native, only uses amount as uint128
        ////////////////////////////////////////////////////
        assembly {
            let amount := shr(128, calldataload(currentOffset))
            // see whether we can get the pre param amount
            switch and(_PRE_PARAM, amount)
            case 1 {
                amount := amountOverride
            }
            default {
                // mask the bitmap
                amount := and(UINT120_MASK, amount)
                // zero is selfbalajnce
                if iszero(amount) {
                    amount := selfbalance()
                }
            }
            if iszero(
                call(
                    gas(),
                    WRAPPED_NATIVE,
                    amount, // ETH to deposit
                    0x0, // no input
                    0x0, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                // revert when native transfer fails
                mstore(0, WRAP)
                revert(0, 0x4)
            }
            currentOffset := add(currentOffset, 16)
        }
        return currentOffset;
    }

    /*
     * | Offset | Length (bytes) | Description         |
     * |--------|----------------|---------------------|
     * | 0      | 20             | receiver            |
     * | 20     | 1              | config              |
     * | 21     | 16             | amount              |
     */
    function _unwrap(uint256 currentOffset, uint256 preParam) internal virtual returns (uint256) {
        ////////////////////////////////////////////////////
        // Transfers either token or native balance from this
        // contract to receiver. Reverts if minAmount is
        // less than the contract balance
        //  config
        //  0: sweep balance and validate against amount
        //     fetches the balance and checks balance >= amount
        //  1: transfer amount to receiver, skip validation
        ////////////////////////////////////////////////////
        assembly {
            // load receiver
            let receiver := shr(96, calldataload(currentOffset))
            // load so that amount is in the lower 14 bytes already
            let providedAmount := calldataload(add(currentOffset, 5))
            // load config
            let config := and(UINT8_MASK, shr(128, providedAmount))
            // mask amount
            providedAmount := and(UINT128_MASK, providedAmount)

            let transferAmount
            // check if we use the override
            switch and(_PRE_PARAM, providedAmount)
            case 1 {
                transferAmount := preParam
            }
            default {
                // mask away the top bitmap
                providedAmount := and(UINT120_MASK, providedAmount)
                // validate if config is zero, otherwise skip
                switch config
                case 0 {
                    // selector for balanceOf(address)
                    mstore(0x0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x4, address())

                    // call to underlying
                    pop(staticcall(gas(), WRAPPED_NATIVE, 0x0, 0x24, 0x0, 0x20))

                    transferAmount := mload(0x0)
                    if lt(transferAmount, providedAmount) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                default {
                    transferAmount := providedAmount
                }
            }

            if gt(transferAmount, 0) {
                // selector for withdraw(uint256)
                mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, transferAmount)
                // should not fail since WRAPPED_NATIVE is immutable
                if iszero(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        0x0, // no ETH
                        0x0, // start of data
                        0x24, // input size = selector plus amount
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // should only revert if receiver cannot receive native
                    mstore(0, NATIVE_TRANSFER)
                    revert(0, 0x4)
                }
                // transfer to receiver if different from this address
                if xor(receiver, address()) {
                    // transfer native to receiver
                    if iszero(
                        call(
                            gas(),
                            receiver,
                            transferAmount,
                            0x0, // input = empty for fallback
                            0x0, // input size = zero
                            0x0, // output = empty
                            0x0 // output size = zero
                        )
                    ) {
                        // should only revert if receiver cannot receive native
                        mstore(0, NATIVE_TRANSFER)
                        revert(0, 0x4)
                    }
                }
            }
            currentOffset := add(currentOffset, 37)
        }
        return currentOffset;
    }

    /** This one is for overring the DEX implementation */
    function _wrapOrUnwrapSimple(uint256 amount, uint256 currentOffset) internal virtual returns (uint256, uint256) {
        assembly {
            /**
             * wrap: 1
             * unwrap: 0
             */
            let wrap := shr(248, calldataload(currentOffset))
            switch wrap
            case 0 {
                // selector for withdraw(uint256)
                mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, amount)
                // should not fail since WRAPPED_NATIVE is immutable
                if iszero(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        0x0, // no ETH
                        0x0, // start of data
                        0x24, // input size = selector plus amount
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // revert when native transfer fails
                    mstore(0, WRAP)
                    revert(0, 0x4)
                }
            }
            default {
                if iszero(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        amount, // ETH to deposit
                        0x0, // no input
                        0x0, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // revert when native transfer fails
                    mstore(0, WRAP)
                    revert(0, 0x4)
                }
            }
            currentOffset := add(currentOffset, 1)
        }
        return (currentOffset, amount);
    }
}
