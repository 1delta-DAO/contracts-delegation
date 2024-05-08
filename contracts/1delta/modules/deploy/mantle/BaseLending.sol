// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.25;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending {

    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice Withdraw from lender 
    function _withdraw(address _underlying, address _to) internal {
        assembly {
            // selector withdraw(address,uint256,address)
            mstore(0xB00, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // withdraw always all
            mstore(0xB44, _to)
            // call pool
            if iszero(call(gas(), LENDLE_POOL, 0x0, 0xB00, 0x64, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0x0, 0x0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }

    /// @notice Borrow from lender given user address and lender Id
    function _borrow(address _underlying, address _from, uint256 _amount, uint256 _mode) internal {
        assembly {
            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _mode)
            mstore(0xB64, 0x0)
            mstore(0xB84, _from)
            // call pool
            if iszero(call(gas(), LENDLE_POOL, 0x0, 0xB00, 0xA4, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Deposit to lender given user address and lender Id
    function _deposit(address _underlying, address _user, uint256 _amount) internal {
        assembly {
            // selector deposit(address,uint256,address,uint16)
            mstore(0xB00, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _user)
            mstore(0xB64, 0x0)
            // call pool
            if iszero(call(gas(), LENDLE_POOL, 0x0, 0xB00, 0x84, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id
    function _repay(address _underlying, address recipient, uint256 _amount, uint256 mode) internal {
        assembly {
            // selector repay(address,uint256,uint256,address)
            mstore(0xB00, 0x573ade8100000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, mode)
            mstore(0xB64, recipient)
            // call pool
            if iszero(call(gas(), LENDLE_POOL, 0x0, 0xB00, 0x84, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }
}
