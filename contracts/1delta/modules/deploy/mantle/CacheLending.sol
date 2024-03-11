// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {WithStorage} from "../../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple Aave V2 types and reads user address and lenderId from cache
 */
abstract contract CacheLending is WithStorage {
    // helpers to read out cache
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant UINT8_MASK_UPPER = 0xff00000000000000000000000000000000000000000000000000000000000000;

    // lender pool constants
    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice Withdraw from lender by transferFrom collateral tokens from user to this and call withdraw on pool
    ///         user address and lenderId are provided by cache
    function _withdraw(address _underlying, uint256 _amount) internal {
        mapping(bytes32 => address) storage collateralTokens = ls().collateralTokens;
        bytes32 cache = gcs().cache;
        assembly {
            // read user and lender from cache
            let user := and(cache, ADDRESS_MASK_UPPER)
            let _lenderId := shr(248, and(UINT8_MASK_UPPER, cache))
            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0xB00, _underlying)
            mstore8(0xB00, _lenderId)
            mstore(0xB20, collateralTokens.slot)
            let collateralToken := sload(keccak256(0xB00, 0x40))

            // selector for transferFrom(address,address,uint256)
            mstore(0xB00, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, user)
            mstore(0xB24, address())
            mstore(0xB44, _amount)

            let success := call(gas(), collateralToken, 0x0, 0xB00, 0x64, 0xB00, 0x20)

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
                        eq(mload(0xB00), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
            // selector withdraw(address,uint256,address)
            mstore(0xB00, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, caller())
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
            success := call(gas(), pool, 0x0, 0xB00, 0x64, 0xB00, 0x0)
            if iszero(success) {
                rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /// @notice Borrow and send tokens to _to address
    ///         user address and lenderId are provided by cache
    function _borrow(address _underlying, uint256 _amount, uint256 _mode) internal {
        bytes32 cache = gcs().cache;
        assembly {
            // read user and lender from cache
            let user := and(cache, ADDRESS_MASK_UPPER)
            let _lenderId := shr(248, and(UINT8_MASK_UPPER, cache))

            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _mode)
            mstore(0xB64, 0x0)
            mstore(0xB84, user)
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
            let success := call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)
            let rdsize
            if iszero(success) {
                rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }

            // selector for transfer(address,uint256)
            mstore(0xB00, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, caller())
            mstore(0xB24, _amount)

            success := call(gas(), _underlying, 0, 0xB00, 0x44, 0xB00, 32)

            rdsize := returndatasize()

            // Check for ERC20 success. ERC20 tokens should return a boolean,
            // but some don't. We accept 0-length return data as success, or at
            // least 32 bytes that starts with a 32-byte boolean true.
            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(0xB00), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Deposit funds to lender for a user
    ///         user address and lenderId are provided by cache
    function _deposit(address _underlying, uint256 _amount) internal {
        bytes32 cache = gcs().cache;
        assembly {
            // read user and lender from cache
            let user := and(cache, ADDRESS_MASK_UPPER)
            let _lenderId := shr(248, and(UINT8_MASK_UPPER, cache))

            // selector deposit(address,uint256,address,uint16)
            mstore(0xB00, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, user)
            mstore(0xB64, 0x0)
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
            if iszero(call(gas(), pool, 0x0, 0xB00, 0x84, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Repay a borrow balance of a lender for a user
    ///         user address and lenderId are provided by cache
    function _repay(address _underlying, uint256 _amount, uint256 mode) internal {
        bytes32 cache = gcs().cache;
        assembly {
            // read user and lender from cache
            let user := and(cache, ADDRESS_MASK_UPPER)
            let _lenderId := shr(248, and(UINT8_MASK_UPPER, cache))

            // selector repay(address,uint256,uint256,address)
            mstore(0xB00, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, mode)
            mstore(0xB64, user)
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
            if iszero(call(gas(), pool, 0x0, 0xB00, 0x84, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }
}
