// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

import {Slots} from "./storage/Slots.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is Slots {
    // lender pool addresses
    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function _withdraw(address _underlying, address _from, address _to, uint256 amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)

            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, COLLATERAL_TOKENS_SLOT)
            let collateralToken := sload(keccak256(0x0, 0x40))

            /** PREPARE TRANSFER_FROM USER */

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _from)
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
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), amount)
            mstore(add(ptr, 0x44), _to)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := LENDLE_POOL
            }
            default {
                pool := AURELIUS_POOL
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
                pool := LENDLE_POOL
            }
            default {
                pool := AURELIUS_POOL
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
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
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
    function _deposit(address _underlying, address _user, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // selector deposit(address,uint256,address,uint16)
            mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), _user)
            mstore(add(ptr, 0x64), 0x0)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := LENDLE_POOL
            }
            default {
                pool := AURELIUS_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id from cache
    function _repay(address _underlying, address recipient, uint256 _amount, uint256 mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // selector repay(address,uint256,uint256,address)
            mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), _underlying)
            mstore(add(ptr, 0x24), _amount)
            mstore(add(ptr, 0x44), mode)
            mstore(add(ptr, 0x64), recipient)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := LENDLE_POOL
            }
            default {
                pool := AURELIUS_POOL
            }
            // call pool
            if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /** BALANCE FETCHERS FOR ALL IN / OUT */

    function _variableDebtBalance(address underlying, address user, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            mstore(0x0, underlying)
            mstore8(0x0, lenderId)
            mstore(0x20, VARIABLE_DEBT_TOKENS_SLOT)
            let debtToken := sload(keccak256(0x0, 0x40))
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, user)

            // call to debtToken
            pop(staticcall(gas(), debtToken, 0x0, 0x24, 0x0, 0x20))

            callerBalance := mload(0x0)
        }
    }

    function _stableDebtBalance(address underlying, address user, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            mstore(0x0, underlying)
            mstore8(0x0, lenderId)
            mstore(0x20, STABLE_DEBT_TOKENS_SLOT)
            let debtToken := sload(keccak256(0x0, 0x40))
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, user)

            // call to debtToken
            pop(staticcall(gas(), debtToken, 0x0, 0x24, 0x0, 0x20))

            callerBalance := mload(0x0)
        }
    }

    function _callerCollateralBalance(address underlying, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            mstore(0x0, underlying)
            mstore8(0x0, lenderId)
            mstore(0x20, COLLATERAL_TOKENS_SLOT)
            let collateralToken := sload(keccak256(0x0, 0x40))
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add caller address as parameter
            mstore(0x4, caller())
            // call to collateralToken
            pop(staticcall(gas(), collateralToken, 0x0, 0x24, 0x0, 0x20))

            callerBalance := mload(0x0)
        }
    }

    function _balanceOfThis(address underlying) internal view returns (uint256 callerBalance) {
        assembly {
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, address())

            // call to underlying
            pop(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20))

            callerBalance := mload(0x0)
        }
    }
}
