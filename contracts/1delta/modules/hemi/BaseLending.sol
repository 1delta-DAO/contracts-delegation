// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../shared/storage/Slots.sol";
import {ERC20Selectors} from "../shared/selectors/ERC20Selectors.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is Slots, ERC20Selectors {
    // errors
    error BadLender();

    // id thresholds, strict upper limit
    uint256 internal constant MAX_ID_AAVE_V3 = 1000; // 0-1000
    uint256 internal constant MAX_ID_AAVE_V2 = 2000; // 1000-2000
    uint256 internal constant MAX_ID_COMPOUND_V3 = 3000; // 2000-3000
    uint256 internal constant MAX_ID_VENUS = 4000; // 3000-4000

    // wNative
    address internal constant WRAPPED_NATIVE = 0x4200000000000000000000000000000000000006;

    // Aave V3 style lender pool addresses
    address internal constant LENDOS = 0xaA397b29510a7219A0f3f7cE3eb53A09bc2A924c;

    // BadLender()
    bytes4 internal constant BAD_LENDER = 0x603b7f3e;

    /// @notice Withdraw from lender lastgiven user address and lender Id
    function _withdraw(address _underlying, address _from, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // Aave types need to trasfer collateral tokens
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
                // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
                mstore(0x0, or(shl(240, _lenderId), _underlying))
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
                case 10 {
                    pool := LENDOS
                }
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    pool := sload(keccak256(0x0, 0x40))
                    if iszero(pool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // call pool
                if iszero(call(gas(), pool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
            default {
                mstore(0, BAD_LENDER)
                revert(0, 0x4)
            }
        }
    }

    /// @notice Borrow from lender lastgiven user address and lender Id
    function _borrow(address _underlying, address _from, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)

            let pool
            switch _lenderId
            case 10 {
                pool := LENDOS
            }
            default {
                mstore(0x0, _lenderId)
                mstore(0x20, LENDING_POOL_SLOT)
                pool := sload(keccak256(0x0, 0x40))
                if iszero(pool) {
                    mstore(0, BAD_LENDER)
                    revert(0, 0x4)
                }
            }
            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(ptr, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), _mode)
            mstore(add(ptr, 0x64), 0x0)
            mstore(add(ptr, 0x84), _from)
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0xA4, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
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

    /// @notice Deposit to lender lastgiven user address and lender Id
    function _deposit(address _underlying, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)

            switch lt(_lenderId, MAX_ID_AAVE_V3)
            case 1 {
                // selector supply(address,uint256,address,uint16)
                mstore(ptr, 0x617ba03700000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _underlying)
                mstore(add(ptr, 0x24), _amount)
                mstore(add(ptr, 0x44), _to)
                mstore(add(ptr, 0x64), 0x0)
                let pool
                // assign lending pool
                switch _lenderId
                case 10 {
                    pool := LENDOS
                }
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    pool := sload(keccak256(0x0, 0x40))
                    if iszero(pool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // call pool
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
            default {
                mstore(0, BAD_LENDER)
                revert(0, 0x4)
            }
        }
    }

    /// @notice Repay to lender lastgiven user address and lender Id
    function _repay(address _underlying, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
                // assign lending pool

                let pool
                switch _lenderId
                case 10 {
                    pool := LENDOS
                }
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    pool := sload(keccak256(0x0, 0x40))
                    if iszero(pool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // selector repay(address,uint256,uint256,address)
                mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _underlying)
                mstore(add(ptr, 0x24), _amount)
                mstore(add(ptr, 0x44), _mode)
                mstore(add(ptr, 0x64), _to)
                // call pool
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
            default {
                mstore(0, BAD_LENDER)
                revert(0, 0x4)
            }
        }
    }
}
