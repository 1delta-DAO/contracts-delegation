// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending {
    // this is the slot for the cache
    bytes32 private constant CACHE_SLOT = 0x468881cf549dc8cc10a98ff7dab63b93cde29208fb93e08f19acee97cac5ba05;
    
    // masks
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    // lender pool addresses
    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function _withdraw(address _underlying, address _to, uint256 amount, uint256 _lenderId) internal {
        assembly {
            // selector withdraw(address,uint256,address)
            mstore(0xB00, 0x69328dec00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, amount)
            mstore(0xB44, _to)
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
            // selector borrow(address,uint256,uint256,uint16,address)
            mstore(0xB00, 0xa415bcad00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _mode)
            mstore(0xB64, 0x0)
            mstore(0xB84, _from)
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
            if iszero(call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x0)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0x0, rdsize)
                revert(0xB00, rdsize)
            }
        }
    }

    /// @notice Deposit to lender given user address and lender Id from cache
    function _deposit(address _underlying, address _user, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            // selector deposit(address,uint256,address,uint16)
            mstore(0xB00, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, _underlying)
            mstore(0xB24, _amount)
            mstore(0xB44, _user)
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

    /// @notice Withdraw from lender by transferFrom collateral tokens from user to this and call withdraw on pool
    ///         user address and lenderId are provided by cache
    function _preWithdraw(address _underlying, address user, uint256 _amount, uint256 lenderId) internal {
        assembly {
            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0xB00, _underlying)
            mstore8(0xB00, lenderId)
            // mstore(0xB20, collateralTokens.slot)
            mstore(0xB20, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
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
        }
    }

    function getCachedAddress() internal view returns (address cachedAddress) {
        assembly {
            cachedAddress := and(sload(CACHE_SLOT), ADDRESS_MASK_UPPER)
        }
    }

    /** BALANCE FETCHERS FOR ALL IN / OUT */

    function _variableDebtBalance(address underlying, address user, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying)
            mstore8(ptr, lenderId)
            // mstore(add(ptr, 0x20), debtTokens.slot)
            mstore(add(ptr, 0x20), 0x70a0823100000000000000000000000000000000000000000000000000000000)
            let debtToken := sload(keccak256(ptr, 0x40))
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), user)

            // call to debtToken
            pop(staticcall(gas(), debtToken, ptr, 0x24, ptr, 0x20))

            callerBalance := mload(ptr)
        }
    }

    function _stableDebtBalance(address underlying, address user, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying)
            mstore8(ptr, lenderId)
            // mstore(add(ptr, 0x20), stableDebtTokens.slot)
            mstore(add(ptr, 0x20), 0x70a0823100000000000000000000000000000000000000000000000000000000)
            let debtToken := sload(keccak256(ptr, 0x40))
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(ptr, 0x4), user)

            // call to debtToken
            pop(staticcall(gas(), debtToken, ptr, 0x24, ptr, 0x20))

            callerBalance := mload(ptr)
        }
    }

    function _callerCollateralBalance(address underlying, uint8 lenderId) internal view returns (uint256 callerBalance) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            mstore(ptr, underlying)
            mstore8(ptr, lenderId)
            // mstore(add(ptr, 0x20), collateralTokens.slot)
            mstore(add(ptr, 0x20), 0x70a0823100000000000000000000000000000000000000000000000000000000)
            let collateralToken := sload(keccak256(ptr, 0x40))
            // selector for balanceOf(address)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add caller address as parameter
            mstore(add(ptr, 0x4), caller())
            // call to collateralToken
            pop(staticcall(gas(), collateralToken, ptr, 0x24, ptr, 0x20))

            callerBalance := mload(ptr)
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
