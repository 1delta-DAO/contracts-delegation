// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * @title Token transfer contract - should work across all EVMs - user Uniswap style Permit2
 */
contract Transfers is ERC20Selectors, Masks, DeltaErrors {
    bytes32 private constant PERMIT2_TRANSFER_FROM = 0x36c7851600000000000000000000000000000000000000000000000000000000;
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function _permit2TransferFrom(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Transfers tokens froom caller to this address
        // zero amount flags that the entire balance is sent
        ////////////////////////////////////////////////////
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
            let amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
            // when entering 0 as amount, use the callwe balance
            if iszero(amount) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, callerAddress)
                // call to token
                pop(
                    staticcall(
                        gas(),
                        underlying, // token
                        0x0,
                        0x24,
                        0x0,
                        0x20
                    )
                )
                // load the retrieved balance
                amount := mload(0x0)
            }

            let ptr := mload(0x40)

            mstore(ptr, PERMIT2_TRANSFER_FROM)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), underlying)
            if iszero(call(gas(), PERMIT2, 0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            currentOffset := add(currentOffset, 54)
        }
        return currentOffset;
    }

    function _transferFrom(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Transfers tokens froom caller to this address
        // zero amount flags that the entire balance is sent
        ////////////////////////////////////////////////////
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
            let amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
            // when entering 0 as amount, use the callwe balance
            if iszero(amount) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, callerAddress)
                // call to token
                pop(
                    staticcall(
                        gas(),
                        underlying, // token
                        0x0,
                        0x24,
                        0x0,
                        0x20
                    )
                )
                // load the retrieved balance
                amount := mload(0x0)
            }
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), underlying, 0, ptr, 0x64, ptr, 32)

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
                returndatacopy(0, 0, rdsize)
                revert(0, rdsize)
            }
            currentOffset := add(currentOffset, 54)
        }
        return currentOffset;
    }

    function _sweep(uint256 currentOffset) internal returns (uint256) {
        ////////////////////////////////////////////////////
        // Transfers either token or native balance from this
        // contract to receiver. Reverts if minAmount is
        // less than the contract balance
        // native asset is flagge via address(0) as parameter
        // Data layout:
        //      bytes 0-20:                  token (if zero, we assume native)
        //      bytes 20-40:                 receiver
        //      bytes 40-41:                 config
        //                                      0: sweep balance and validate against amount
        //                                         fetches the balance and checks balance >= amount
        //                                      1: transfer amount to receiver, skip validation
        //                                         forwards the ERC20 error if not enough balance
        //      bytes 41-55:                 amount, either validation or transfer amount
        ////////////////////////////////////////////////////
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // we skip shr by loading the address to the lower bytes
            let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
            // load so that amount is in the lower 14 bytes already
            let providedAmount := calldataload(add(currentOffset, 23))
            // load config
            let config := and(UINT8_MASK, shr(112, providedAmount))
            // mask amount
            providedAmount := and(_UINT112_MASK, providedAmount)
            // initialize transferAmount
            let transferAmount

            // zero address is native
            switch iszero(underlying)
            ////////////////////////////////////////////////////
            // Transfer token
            ////////////////////////////////////////////////////
            case 0 {
                // for config = 0, the amount is the balance and we
                // check that the balance is larger tha the amount provided
                switch config
                case 0 {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
                    // call to token
                    pop(
                        staticcall(
                            gas(),
                            underlying,
                            0x0,
                            0x24,
                            0x0,
                            0x20 //
                        )
                    )
                    // load the retrieved balance
                    transferAmount := mload(0x0)
                    // revert if balance is not enough
                    if lt(transferAmount, providedAmount) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                default {
                    transferAmount := providedAmount
                }
                if gt(transferAmount, 0) {
                    let ptr := mload(0x40) // free memory pointer

                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), receiver)
                    mstore(add(ptr, 0x24), transferAmount)

                    let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)

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
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
                    }
                }
            }
            ////////////////////////////////////////////////////
            // Transfer native
            ////////////////////////////////////////////////////
            default {
                switch config
                case 0 {
                    transferAmount := selfbalance()
                    // revert if balance is not enough
                    if lt(transferAmount, providedAmount) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                default {
                    transferAmount := providedAmount
                }
                if gt(transferAmount, 0) {
                    if iszero(
                        call(
                            gas(),
                            receiver,
                            providedAmount,
                            0x0, // input = empty for fallback/receive
                            0x0, // input size = zero
                            0x0, // output = empty
                            0x0 // output size = zero
                        )
                    ) {
                        mstore(0, NATIVE_TRANSFER)
                        revert(0, 0x4) // revert when native transfer fails
                    }
                }
            }
            currentOffset := add(currentOffset, 55)
        }
        return currentOffset;
    }
}
