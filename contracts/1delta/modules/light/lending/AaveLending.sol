// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract AaveLending is Slots, ERC20Selectors, Masks {
    // BadLender()
    bytes4 private constant BAD_LENDER = 0x603b7f3e;

    uint256 private constant _PRE_PARAM = 1 << 127;

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | aToken                          |
     * | 96     | 20             | pool                            |
     */
    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _withdrawFromAave(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            // Aave types need to trasfer collateral tokens

            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))
            // skip amounts
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)

            let amount := and(_UINT112_MASK, amountData)
            // get aToken
            let collateralToken := shr(96, calldataload(currentOffset))
            // skip token
            currentOffset := add(currentOffset, 20)

            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                // apply max if needed
                switch amount
                case 0xffffffffffffffffffffffffffff {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add caller address as parameter
                    mstore(0x04, callerAddress)
                    // call to token
                    pop(
                        staticcall(
                            gas(),
                            collateralToken, // collateral token
                            0x0,
                            0x24,
                            0x0,
                            0x20
                        )
                    )
                    // load the retrieved balance
                    amount := mload(0x0)
                }
            }
            default {
                amount := amountOverride
            }

            /** PREPARE TRANSFER_FROM USER */

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), collateralToken, 0x0, ptr, 0x64, 0x0, 0x20)

            let rdsize := returndatasize()

            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(0x0), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }

            // selector withdraw(address,uint256,address)
            mstore(ptr, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), receiver)

            let pool := shr(96, calldataload(currentOffset))

            // skip token (end of data)
            currentOffset := add(currentOffset, 20)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 1              | mode                            |
     * | 77     | 20             | pool                            |
     */
    function _borrowFromAave(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))
            // skip amounts
            currentOffset := add(currentOffset, 16)
            let receiverAndMode := calldataload(currentOffset)
            // receiver
            let receiver := shr(96, receiverAndMode)
            let mode := and(UINT8_MASK, shr(88, receiverAndMode))
            // skip receiver & mode
            currentOffset := add(currentOffset, 21)
            // get pool
            let pool := shr(96, calldataload(currentOffset))
            // skip pool (end of data)
            currentOffset := add(currentOffset, 20)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
            }
            default {
                amount := amountOverride
            }

            let ptr := mload(0x40)
            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(ptr, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), mode)
            mstore(add(ptr, 0x64), 0x0)
            mstore(add(ptr, 0x84), callerAddress)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0xA4, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            //  transfer underlying if needed
            if xor(receiver, address()) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                // mstore(add(ptr, 0x24), amount) <-- this one is still in this memo location

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
        return currentOffset;
    }

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | pool                            |
     */
    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _depositToAaveV3(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))
            // skip amounts
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)
            // get pool
            let pool := shr(96, calldataload(currentOffset))
            // skip pool (end of data)
            currentOffset := add(currentOffset, 20)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
                // zero is this balance
                if iszero(amount) {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
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
            }
            default {
                amount := amountOverride
            }

            let ptr := mload(0x40)

            /**
             * Approve pool beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, pool)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector supply(address,uint256,address,uint16)
            mstore(ptr, 0x617ba03700000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), receiver)
            mstore(add(ptr, 0x64), 0x0)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | pool                            |
     */
    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _depositToAaveV2(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))
            // skip amounts
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)
            // get pool
            let pool := shr(96, calldataload(currentOffset))
            // skip pool (end of data)
            currentOffset := add(currentOffset, 20)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
                // zero is this balance
                if iszero(amount) {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
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
            }
            default {
                amount := amountOverride
            }

            let ptr := mload(0x40)

            /**
             * Approve pool beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, pool)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector deposit(address,uint256,address,uint16)
            mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), receiver)
            mstore(add(ptr, 0x64), 0x0)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 1              | mode                            |
     * | 76     | 20             | debtToken                       |
     * | 97     | 20             | pool                            |
     */
    function _repayToAave(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))
            // skip amounts
            currentOffset := add(currentOffset, 16)
            let receiverAndMode := calldataload(currentOffset)
            // receiver
            let receiver := shr(96, receiverAndMode)
            let mode := and(UINT8_MASK, shr(88, receiverAndMode))
            // skip receiver & mode
            currentOffset := add(currentOffset, 21)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
                switch amount
                case 0 {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
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
                case 0xffffffffffffffffffffffffffff {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add caller address as parameter
                    mstore(0x04, callerAddress)
                    // call to token
                    pop(
                        staticcall(
                            gas(),
                            shr(96, calldataload(currentOffset)), // debt token
                            0x0,
                            0x24,
                            0x0,
                            0x20
                        )
                    )
                    // load the retrieved balance
                    amount := mload(0x0)
                }
            }
            default {
                amount := amountOverride
            }
            // skip debt token
            currentOffset := add(currentOffset, 20)
            // get pool
            let pool := shr(96, calldataload(currentOffset))
            // skip pool (end of data)
            currentOffset := add(currentOffset, 20)

            let ptr := mload(0x40)

            /**
             * Approve aave pool beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, pool)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector repay(address,uint256,uint256,address)
            mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), mode)
            mstore(add(ptr, 0x64), receiver)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }

        return currentOffset;
    }
}
