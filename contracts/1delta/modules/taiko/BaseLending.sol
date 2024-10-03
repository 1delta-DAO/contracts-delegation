// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.27;

import {Slots} from "./storage/Slots.sol";
import {SyncSwapper} from "./swappers/SyncType.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is Slots, SyncSwapper {

    // wNative
    address internal constant WRAPPED_NATIVE = 0xA51894664A773981C6C112C43ce576f315d5b1B6;

    // lender pool addresses
    address internal constant HANA_POOL = 0x4aB85Bf9EA548410023b25a13031E91B4c4f3b91;
    address internal constant MERIDIAN_POOL = 0x1697A950a67d9040464287b88fCa6cb5FbEC09BA;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function _withdraw(address _underlying, address _from, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)

            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, COLLATERAL_TOKENS_SLOT)
            let collateralToken := sload(keccak256(0x0, 0x40))

            /** PREPARE TRANSFER_FROM USER */

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), _from)
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), _amount)

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
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), _to)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := HANA_POOL
            }
            default {
                pool := MERIDIAN_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /// @notice Borrow from lender given user address and lender Id from cache
    function _borrow(address _underlying, address _from, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(ptr, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), _mode)
            mstore(add(ptr, 0x64), 0x0)
            mstore(add(ptr, 0x84), _from)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := HANA_POOL
            }
            default {
                pool := MERIDIAN_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0xA4, 0x0, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
            //  transfer underlying if needed
            if xor(_to, address()) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), _to)
                mstore(add(ptr, 0x24), _amount)

                let success := call(gas(), _underlying, 0, ptr, 0x44, ptr, 32)

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
    }

    /// @notice Deposit to lender given user address and lender Id from cache
    function _deposit(address _underlying, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // selector deposit(address,uint256,address,uint16)
            mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), _to)
            mstore(add(ptr, 0x64), 0x0)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := HANA_POOL
            }
            default {
                pool := MERIDIAN_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id from cache
    function _repay(address _underlying, address _to, uint256 _amount, uint256 mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // selector repay(address,uint256,uint256,address)
            mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), mode)
            mstore(add(ptr, 0x64), _to)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := HANA_POOL
            }
            default {
                pool := MERIDIAN_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }
}
