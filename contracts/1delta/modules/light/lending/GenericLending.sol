// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {LendingConstants} from "./LendingConstants.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract GenericLending is Slots, ERC20Selectors, Masks {

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
     * | 76     | 1              | isBase                          |
     * | 77     | 20             | pool                            |
     */
    function _withdrawFromCompoundV3(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            // Compound V3 types need to trasfer collateral tokens

            let underlying := shr(96, calldataload(currentOffset))
            // offset for amoutn at lower bytes
            currentOffset := add(currentOffset, 20)
            let amountData := shr(128, calldataload(currentOffset))

            // skip amounts
            currentOffset := add(currentOffset, 16)
            let isBase := calldataload(currentOffset)
            // receiver
            let receiver := shr(96, isBase)

            // skip receiver and isBase flag
            currentOffset := add(currentOffset, 21)

            // adjust isBase flag

            let cometPool := shr(96, calldataload(currentOffset))

            // skip base comet
            currentOffset := add(currentOffset, 20)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
                if eq(amount, 0xffffffffffffffffffffffffffff) {
                    switch and(UINT8_MASK, shr(88, isBase))
                    case 0 {
                        // selector for userCollateral(address,address)
                        mstore(ptr, 0x2b92a07d00000000000000000000000000000000000000000000000000000000)
                        // add caller address as parameter
                        mstore(add(ptr, 0x04), callerAddress)
                        // add underlying address
                        mstore(add(ptr, 0x24), underlying)
                        // call to token
                        pop(
                            staticcall(
                                gas(),
                                cometPool, // collateral token
                                ptr,
                                0x44,
                                ptr,
                                0x20
                            )
                        )
                        // load the retrieved balance (lower 128 bits)
                        amount := and(UINT128_MASK, mload(ptr))
                    }
                    // comet.balanceOf(...) is lending token balance
                    default {
                        // selector for balanceOf(address)
                        mstore(0, ERC20_BALANCE_OF)
                        // add caller address as parameter
                        mstore(0x04, callerAddress)
                        // call to token
                        pop(
                            staticcall(
                                gas(),
                                cometPool, // collateral token
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
            }
            default {
                amount := amountOverride
            }

            // selector withdrawFrom(address,address,address,uint256)
            mstore(ptr, 0x2644131800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), underlying)
            mstore(add(ptr, 0x64), amount)
            // call pool
            if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
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
     * | 76     | 20             | comet                           |
     */
    function _borrowFromCompoundV3(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            // Compound V3 types need to trasfer collateral tokens
            let underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // offset for amoutn at lower bytes
            let amountData := shr(128, calldataload(currentOffset))
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)

            let cometPool := shr(96, calldataload(currentOffset))

            // skip base comet
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

            // selector withdrawFrom(address,address,address,uint256)
            mstore(ptr, 0x2644131800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), underlying)
            mstore(add(ptr, 0x64), amount)
            // call pool
            if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /*
     * Note this is for Venus Finance only as other COmpound forks
     * do not have this feature.
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | cToken                          |
     */
    function _borrowFromCompoundV2(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            // Compound V3 types need to trasfer collateral tokens
            let underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // offset for amoutn at lower bytes
            let amountData := shr(128, calldataload(currentOffset))
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)

            let cToken := shr(96, calldataload(currentOffset))

            // skip cToken
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

            // selector for borrowBehlaf(address,uint256)
            mstore(ptr, 0x856e5bb300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), callerAddress) // user
            mstore(add(ptr, 0x24), amount) // to this address
            if iszero(
                call(
                    gas(),
                    cToken,
                    0x0, // no ETH sent
                    ptr, // input selector
                    0x44, // input size = selector + address + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            if xor(address(), receiver) {
                // 4) TRANSFER TO RECIPIENT
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amount)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
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
     * | 76     | 20             | cToken                          |
     */
    function _withdrawFromCompoundV2(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            // Compound V2 types need to trasfer collateral tokens
            let underlying := shr(96, calldataload(currentOffset))
            currentOffset := add(currentOffset, 20)
            // offset for amoutn at lower bytes
            let amountData := shr(128, calldataload(currentOffset))
            currentOffset := add(currentOffset, 16)
            // receiver
            let receiver := shr(96, calldataload(currentOffset))
            // skip receiver
            currentOffset := add(currentOffset, 20)

            let cToken := shr(96, calldataload(currentOffset))

            // skip cToken
            currentOffset := add(currentOffset, 20)

            let amount
            // check if override is used
            switch and(_PRE_PARAM, amountData)
            case 0 {
                amount := and(_UINT112_MASK, amountData)
                if eq(amount, 0xffffffffffffffffffffffffffff) {
                    // selector for balanceOfUnderlying(address)
                    mstore(0, 0x3af9e66900000000000000000000000000000000000000000000000000000000)
                    // add caller address as parameter
                    mstore(0x04, callerAddress)
                    // call to token
                    pop(
                        call(
                            gas(),
                            cToken, // collateral token
                            0x0,
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

            // 1) CALCULTAE TRANSFER AMOUNT
            // Store fnSig (=bytes4(abi.encodeWithSignature("exchangeRateCurrent()"))) at params
            // - here we store 32 bytes : 4 bytes of fnSig and 28 bytes of RIGHT padding
            mstore(
                0x0,
                0xbd6d894d00000000000000000000000000000000000000000000000000000000 // with padding
            )
            // call to collateralToken
            // accrues interest. No real risk of failure.
            pop(
                call(
                    gas(),
                    cToken,
                    0x0,
                    0x0,
                    0x24,
                    0x0, // store back to ptr
                    0x20
                )
            )

            // load the retrieved protocol share
            let refAmount := mload(0x0)

            // calculate collateral token amount, rounding up
            let cTokenTransferAmount := add(
                div(
                    mul(amount, 1000000000000000000), // multiply with 1e18
                    refAmount // divide by rate
                ),
                1
            )
            // FETCH BALANCE
            // selector for balanceOf(address)
            mstore(0x0, ERC20_BALANCE_OF)
            // add _from address as parameter
            mstore(0x4, callerAddress)

            // call to collateralToken
            pop(staticcall(gas(), cToken, 0x0, 0x24, 0x0, 0x20))

            // load the retrieved balance
            refAmount := mload(0x0)

            // floor to the balance
            if gt(cTokenTransferAmount, refAmount) {
                cTokenTransferAmount := refAmount
            }

            // 2) TRANSFER VTOKENS

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), callerAddress) // from user
            mstore(add(ptr, 0x24), address()) // to this address
            mstore(add(ptr, 0x44), cTokenTransferAmount)

            let success := call(gas(), cToken, 0, ptr, 0x64, ptr, 32)

            if iszero(success) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            // 3) REDEEM
            // selector for redeem(uint256)
            mstore(0, 0xdb006a7500000000000000000000000000000000000000000000000000000000)
            mstore(0x4, cTokenTransferAmount)

            if iszero(
                call(
                    gas(),
                    cToken,
                    0x0,
                    0x0, // input = selector
                    0x24, // input selector + uint256
                    0x0, // output
                    0x0 // output size = zero
                )
            ) {
                // returndatacopy(0, 0, returndatasize())
                // revert(0, returndatasize())
            }

            // transfer tokens only if the receiver is not this address
            if xor(address(), receiver) {
                // 4) TRANSFER TO RECIPIENT
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amount)

                success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)

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
                    // returndatacopy(0, 0, rdsize)
                    // revert(0, rdsize)
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
     * | 76     | 20             | cToken                          |
     */
    function _borrowFromVenus(uint256 currentOffset, address callerAddress, uint256 amountOverride) internal returns (uint256) {
        assembly {
            let amountData := and(UINT128_MASK, calldataload(add(currentOffset, 4)))
            let amount := and(_UINT112_MASK, amountData)
            let underlying := shr(96, calldataload(add(currentOffset, 76)))
            let cToken := shr(96, calldataload(add(currentOffset, 76)))
            let receiver := shr(96, calldataload(add(currentOffset, 76)))

            // check if override is used
            if and(_PRE_PARAM, amountData) {
                amount := amountOverride
            }

            let ptr := mload(0x40)
            // selector for borrowBehlaf(address,uint256)
            mstore(ptr, 0x856e5bb300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), callerAddress) // user
            mstore(add(ptr, 0x24), amount) // to this address
            if iszero(
                call(
                    gas(),
                    cToken,
                    0x0, // no ETH sent
                    ptr, // input selector
                    0x44, // input size = selector + address + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            if xor(address(), receiver) {
                // 4) TRANSFER TO RECIPIENT
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amount)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
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
     * Note: Some Compound V2 forks might not have this feature and need a separate
     * function.
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | cToken                          |
     */
    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _depositToCompoundV2(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
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
            // get cToken
            let cToken := shr(96, calldataload(currentOffset))
            // skip cToken (end of data)
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
             * Approve cToken beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, cToken)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), cToken)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector for mintBehalf(address,uint256)
            mstore(ptr, 0x23323e0300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), amount)

            let success := call(
                gas(),
                cToken,
                0x0,
                ptr, //
                0x44, //
                0x0, //
                0x0 // output size = zero
            )

            if iszero(success) {
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
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
     * | 76     | 20             | comet                           |
     */
    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _depositToCompoundV3(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
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
            // get comet
            let comet := shr(96, calldataload(currentOffset))
            // skip comet (end of data)
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
             * Approve comet beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, comet)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), comet)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector supplyTo(address,address,uint256)
            mstore(ptr, 0x4232cd6300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), underlying)
            mstore(add(ptr, 0x44), amount)
            // call pool
            if iszero(call(gas(), comet, 0x0, ptr, 0x64, 0x0, 0x0)) {
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

    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 76     | 20             | cToken                          |
     */
    function _repayToCompoundV2(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
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
            // get comet
            let cToken := shr(96, calldataload(currentOffset))
            // skip comet (end of data)
            currentOffset := add(currentOffset, 20)

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
                    amount := MAX_UINT256
                }
            }
            default {
                amount := amountOverride
            }

            let ptr := mload(0x40)

            /**
             * Approve cToken beforehand if needed
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, cToken)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), cToken)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // selector for repayBorrowBehalf(address,uint256)
            mstore(ptr, 0x2608f81800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), receiver) // user
            mstore(add(ptr, 0x24), amount) // to this address

            if iszero(
                call(
                    gas(),
                    cToken,
                    0x0,
                    ptr, // input = empty for fallback
                    0x44, // input size = selector + address + uint256
                    ptr, // output
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0x0, 0, returndatasize())
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
     * | 76     | 20             | comet                           |
     */
    function _repayToCompoundV3(uint256 currentOffset, uint256 amountOverride) internal returns (uint256) {
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
            // get comet
            let comet := shr(96, calldataload(currentOffset))
            // skip comet (end of data)
            currentOffset := add(currentOffset, 20)

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
                    amount := MAX_UINT256
                }
            }
            default {
                amount := amountOverride
            }

            let ptr := mload(0x40)

            /**
             * Approve comet beforehand
             */
            mstore(0x0, underlying)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, comet)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), comet)
                mstore(add(ptr, 0x24), MAX_UINT256)

                if iszero(call(gas(), underlying, 0x0, ptr, 0x44, 0x0, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }

            // skip pool (end of data)
            currentOffset := add(currentOffset, 20)

            // selector supplyTo(address,address,uint256)
            mstore(ptr, 0x4232cd6300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), underlying)
            mstore(add(ptr, 0x44), amount)
            // call pool
            if iszero(call(gas(), comet, 0x0, ptr, 0x64, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }

        return currentOffset;
    }
}
