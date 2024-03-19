// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {WithStorage} from "../../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types
 *         Reads user address and lenderId from cache
 *         --- ONLY TO BE USED IN CALLBACKS WHERE THE CALLER RECEIVES THE FUNDS ---
 *         For Aave type protocols, we need a transferFrom on the collateral token
 *         before a withdrawal and a regular transfer after a borrow
 */
abstract contract CacheLending is WithStorage {
    // helpers to read out cache
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant UINT8_MASK_UPPER = 0xff00000000000000000000000000000000000000000000000000000000000000;

    // lender pool constants
    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;
    address internal constant REAX_POOL = 0x4bbea708F4e48eB0BB15E0041611d27c3c8638Cf;

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

            /** PREPARE TRANSFER_FROM USER */

            // selector for transferFrom(address,address,uint256)
            mstore(0xB00, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, user)
            mstore(0xB24, address())
            mstore(0xB44, _amount)

            let success := call(gas(), collateralToken, 0x0, 0xB00, 0x64, 0xB00, 0x20)

            let rdsize := returndatasize()

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

            /** PREPARE WITHDRAW */

            // selector withdraw(address,uint256,address)
            mstore(0xB00, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, caller()) // send to caller
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := LENDLE_POOL
                // call pool
                success := call(gas(), pool, 0x0, 0xB00, 0x64, 0xB00, 0x0)
            }
            case 1 {
                pool := AURELIUS_POOL
                // call pool
                success := call(gas(), pool, 0x0, 0xB00, 0x64, 0xB00, 0x0)
            }
            default {
                mstore(0xB64, 0x0)
                pool := REAX_POOL
                // call pool
                success := call(gas(), pool, 0x0, 0xB00, 0x64, 0xB00, 0x0)
            }
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

            /** PREPARE BORROW */

            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _mode)
            mstore(0xB64, 0x0)
            mstore(0xB84, user)
            let pool
            let success
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := LENDLE_POOL
                success := call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)
            }
            case 1 {
                pool := AURELIUS_POOL
                success := call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)
            }
            default {
                pool := REAX_POOL
                mstore(0xBA4, 0x0)
                success := call(gas(), pool, 0x0, 0xB00, 0xC4, 0xB00, 0x0)
            }
            // call pool
            let rdsize
            if iszero(success) {
                rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }

            /** PREPARE TRANSFER */

            // selector for transfer(address,uint256)
            mstore(0xB00, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, caller()) // send to caller
            mstore(0xB24, _amount)

            success := call(gas(), _underlying, 0x0, 0xB00, 0x44, 0xB00, 32)

            rdsize := returndatasize()

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

            /** PREPARE DEPOSIT */

            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                // selector deposit(address,uint256,address,uint16)
                mstore(0xB00, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
                pool := LENDLE_POOL
            }
            case 1 {
                // selector deposit(address,uint256,address,uint16)
                mstore(0xB00, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
                pool := AURELIUS_POOL
            }
            default {
                // selector supply(address,uint256,address,uint16)
                mstore(0xB00, 0x617ba03700000000000000000000000000000000000000000000000000000000)
                pool := REAX_POOL
            }
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, user)
            mstore(0xB64, 0x0)
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

            /** PREPARE REPAY */

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
            case 1 {
                pool := AURELIUS_POOL
            }
            default {
                pool := REAX_POOL
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
