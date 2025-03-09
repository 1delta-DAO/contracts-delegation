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

    function _wrap(uint256 currentOffset) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Wrap native, only uses amount as uint112
        ////////////////////////////////////////////////////
        assembly {
            let amount := shr(144, calldataload(currentOffset))
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
            currentOffset := add(currentOffset, 14)
        }
        return currentOffset;
    }

    function _unwrap(uint256 currentOffset) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Transfers either token or native balance from this
        // contract to receiver. Reverts if minAmount is
        // less than the contract balance
        // native asset is flagge via address(0) as parameter
        //      bytes 1-20:                 receiver
        //      bytes 20-21:                 config
        //                                      0: sweep balance and validate against amount
        //                                         fetches the balance and checks balance >= amount
        //                                      1: transfer amount to receiver, skip validation
        //      bytes 21-35:                 amount, either validation or transfer amount
        ////////////////////////////////////////////////////
        assembly {
            let receiver := shr(96, calldataload(currentOffset))
            let providedAmount := calldataload(add(currentOffset, 3))
            // load config
            let config := and(UINT8_MASK, shr(112, providedAmount))
            providedAmount := and(_UINT112_MASK, providedAmount)

            let transferAmount
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
            if gt(transferAmount, 0) {
                // selector for withdraw(uint256)
                mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, transferAmount)
                // should not fail since WRAPPED_NATIVE is immutable
                pop(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        0x0, // no ETH
                        0x0, // start of data
                        0x24, // input size = selector plus amount
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                )
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
            currentOffset := add(currentOffset, 35)
        }
        return currentOffset;
    }
}
