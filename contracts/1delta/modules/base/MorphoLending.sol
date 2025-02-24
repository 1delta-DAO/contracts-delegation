// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../shared/storage/Slots.sol";
import {ERC20Selectors} from "../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../shared/masks/Masks.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Morpho Blue
 */
abstract contract Morpho is Slots, ERC20Selectors, Masks {
    address internal constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /**
     * Layout:
     * [market|amount|receiver|calldataLength|calldata]
     */

    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _morphoBorrow(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptr := mload(0x40)

            // borrow(...)
            mstore(ptr, 0x50d8cd4b00000000000000000000000000000000000000000000000000000000)

            // market stuff

            currentOffset := add(currentOffset, 1)
            // tokens
            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken

            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken

            // oralce and irm
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm

            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)

            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let borrowAm := and(UINT120_MASK, lltvAndAmount)

            /** check if it is by shares or assets */
            switch and(UINT8_MASK, shr(120, lltvAndAmount))
            case 0 {
                mstore(add(ptr, 164), borrowAm) // assets
                mstore(add(ptr, 196), 0) // shares
            }
            default {
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), borrowAm) // shares
            }
            currentOffset := add(currentOffset, 32)

            // onbehalf
            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            let lastBit := calldataload(currentOffset)
            mstore(add(ptr, 260), shr(96, lastBit)) // receiver
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 292), 0x140) // offset

            let calldataLength := and(UINT16_MASK, shr(80, lastBit))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 356), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 376), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            mstore(add(ptr, 324), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 376), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }

        return currentOffset;
    }

    /// @notice Deposit to Morpho Blue - add calldata if length is nonzero
    function _morphoDeposit(uint256 currentOffset, address callerAddress, address token) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptr := mload(0x40)

            // supplyCollateral(...)
            mstore(ptr, 0x238d657900000000000000000000000000000000000000000000000000000000)

            // market stuff

            currentOffset := add(currentOffset, 1)
            // tokens
            mstore(add(ptr, 4), shr(96, calldataload(currentOffset))) // MarketParams.loanToken
            mstore(add(ptr, 36), token) // MarketParams.collateralToken

            // oralce and irm
            currentOffset := add(currentOffset, 40)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm

            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)

            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let amountToDeposit := and(UINT128_MASK, lltvAndAmount)

            /** if the amount is zero, we assume that the contract balance is deposited */
            if iszero(amountToDeposit) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, address())
                // call to token
                pop(
                    staticcall(
                        gas(),
                        token, // collateral token
                        0x0,
                        0x24,
                        0x0,
                        0x20
                    )
                )
                // load the retrieved balance
                amountToDeposit := mload(0x0)
            }

            // amount
            mstore(add(ptr, 164), and(UINT128_MASK, lltvAndAmount)) // assets

            // onbehalf
            mstore(add(ptr, 196), callerAddress) // onBehalfOf
            mstore(add(ptr, 228), 0x100) // offset

            currentOffset := add(currentOffset, 32)

            let calldataLength := and(UINT16_MASK, shr(240, currentOffset))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 292), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 312), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            mstore(add(ptr, 260), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 312), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /**
     * Layout:
     * [market|amount|receiver|calldataLength|calldata]
     */

    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _morphoRepay(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // morpho should be the primary choice
            let ptrBase := mload(0x40)
            let ptr := add(ptrBase, 128)

            currentOffset := add(currentOffset, 1)

            let token := shr(96, calldataload(currentOffset))
            /**
             * Approve MB beforehand for the repay amount
             */
            mstore(0x0, token)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, MORPHO_BLUE)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptrBase, ERC20_APPROVE)
                mstore(add(ptrBase, 0x04), MORPHO_BLUE)
                mstore(add(ptrBase, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

                if iszero(call(gas(), token, 0x0, ptrBase, 0x44, ptrBase, 0x0)) {
                    revert(0x0, 0x0)
                }
                sstore(key, 1)
            }
            // market stuff

            // repay(...)
            mstore(ptr, 0x20b76e8100000000000000000000000000000000000000000000000000000000)
            // tokens
            mstore(add(ptr, 4), token) // MarketParams.loanToken

            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 36), shr(96, calldataload(currentOffset))) // MarketParams.collateralToken

            // oralce and irm
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 68), shr(96, calldataload(currentOffset))) // MarketParams.oracle
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 100), shr(96, calldataload(currentOffset))) // MarketParams.irm

            currentOffset := add(currentOffset, 20)
            let lltvAndAmount := calldataload(currentOffset)

            mstore(add(ptr, 132), shr(128, lltvAndAmount)) // MarketParams.lltv

            let marketId := keccak256(add(ptr, 4), 160)

            let repayAm := and(UINT120_MASK, lltvAndAmount)

            /** check if it is by shares or assets */
            switch and(UINT8_MASK, shr(120, lltvAndAmount))
            case 0 {
                mstore(add(ptr, 164), repayAm) // assets
                mstore(add(ptr, 196), 0) // shares
            }
            default {
                mstore(add(ptr, 164), 0) // assets
                mstore(add(ptr, 196), repayAm) // shares
            }
            currentOffset := add(currentOffset, 32)

            // onbehalf
            mstore(add(ptr, 228), callerAddress) // onBehalfOf
            mstore(add(ptr, 260), 0x120) // offset

            let calldataLength := and(UINT16_MASK, shr(80, calldataload(currentOffset)))
            currentOffset := add(currentOffset, 2)

            // add calldata if needed
            if xor(0, calldataLength) {
                calldataLength := add(calldataLength, 20)
                mstore(add(ptr, 324), shl(96, callerAddress)) // caller
                calldatacopy(add(ptr, 344), currentOffset, calldataLength) // calldata
                currentOffset := add(currentOffset, calldataLength)
            }

            mstore(add(ptr, 292), calldataLength) // calldatalength
            if iszero(
                call(
                    gas(),
                    MORPHO_BLUE,
                    0x0,
                    ptr,
                    add(calldataLength, 344), // = 10 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                // let rdlen := returndatasize()
                // returndatacopy(0, 0, rdlen)
                // revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }
}
