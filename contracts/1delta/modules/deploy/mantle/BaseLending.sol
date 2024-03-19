// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {WithStorage} from "../../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is WithStorage {
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant UINT8_MASK_UPPER = 0xff00000000000000000000000000000000000000000000000000000000000000;

    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;
    address internal constant REAX_POOL = 0x4bbea708F4e48eB0BB15E0041611d27c3c8638Cf;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function _withdraw(address _underlying, address _to, uint256 _lenderId) internal {
        assembly {
            // selector withdraw(address,uint256,address)
            mstore(0xB00, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // withdraw always all
            mstore(0xB44, _to)
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
            if iszero(call(gas(), pool, 0x0, 0xB00, 0x64, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /// @notice Borrow from lender given user address and lender Id from cache
    function _borrow(address _underlying, address _from, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let pool
            let success
            // assign lending pool
            switch _lenderId
            case 0 {
                // selector borrow(address,uint256,uint256,uint16,address)
                mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, _underlying)
                mstore(0xB24, _amount)
                mstore(0xB44, _mode)
                mstore(0xB64, 0x0)
                mstore(0xB84, _from)
                pool := LENDLE_POOL
                success := call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)
            }
            case 1 {
                // selector borrow(address,uint256,uint256,uint16,address)
                mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, _underlying)
                mstore(0xB24, _amount)
                mstore(0xB44, _mode)
                mstore(0xB64, 0x0)
                mstore(0xB84, _from)
                pool := AURELIUS_POOL
                success := call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)
            }
            default {
                pool := REAX_POOL
                // selector borrow(address,uint256,uint256,uint16,address,bytes[])
                mstore(0xB00, 0x3fa01eab00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, _underlying)
                mstore(0xB24, _amount)
                mstore(0xB44, _mode)
                mstore(0xB64, 0x0)
                mstore(0xB84, _from)
                mstore(0xBA4, 0x80)
                mstore(0xBC4, 0x0)
                success := call(gas(), pool, 0x0, 0xB00, 0x80, 0xB00, 0x0)
            }
            // call pool
            if iszero(success) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Deposit to lender given user address and lender Id from cache
    function _deposit(address _underlying, uint256 _amount, address _user, uint256 _lenderId) internal {
        assembly {
            let pool
            // assign lending pool and selector
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
            mstore(0xB44, _user)
            mstore(0xB64, 0x0)

            // call pool
            if iszero(call(gas(), pool, 0x0, 0xB00, 0x84, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id from cache
    function _repay(address _underlying, address recipient, uint256 _amount, uint256 mode, uint256 _lenderId) internal {
        assembly {
            // selector repay(address,uint256,uint256,address)
            mstore(0xB00, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, mode)
            mstore(0xB64, recipient)
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
