// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {BalancerSwapper} from "./swappers/Balancer.sol";
import {Slots} from "../shared/storage/Slots.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is Slots, BalancerSwapper {
    // errors
    error BadLender();

    // wNative
    address internal constant WRAPPED_NATIVE = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // lender pool addresses
    address internal constant AAVE_V3 = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant AAVE_V2 = 0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf;
    address internal constant YLDR = 0x8183D4e0561cBdc6acC0Bdb963c352606A2Fa76F;

    // Compound V3 addresses
    address internal constant COMET_USDC = 0xF25212E676D1F7F89Cd72fFEe66158f541246445;
    address internal constant COMET_USDT = 0xaeB318360f27748Acb200CE616E389A6C9409a07;

    // BadLender()
    bytes4 internal constant BAD_LENDER = 0x603b7f3e;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function _withdraw(address _underlying, address _from, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // Aave types need to trasfer collateral tokens
            switch lt(_lenderId, 50)
            case 1 {
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
                    pool := AAVE_V3
                }
                case 1 {
                    pool := YLDR
                }
                case 25 {
                    pool := AAVE_V2
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
                let cometPool
                switch _lenderId
                case 50 {
                    cometPool := COMET_USDC
                }
                case 51 {
                    cometPool := COMET_USDT
                }
                // default: load comet from storage
                // if it is not provided directly
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    cometPool := sload(keccak256(0x0, 0x40))
                    if iszero(cometPool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // selector withdrawFrom(address,address,address,uint256)
                mstore(ptr, 0x2644131800000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _from)
                mstore(add(ptr, 0x24), _to)
                mstore(add(ptr, 0x44), _underlying)
                mstore(add(ptr, 0x64), _amount)
                // call pool
                if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
        }
    }

    /// @notice Borrow from lender given user address and lender Id from cache
    function _borrow(address _underlying, address _from, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, 50)
            case 1 {
                switch _lenderId
                case 1 {
                    // YLDR has no borrow mode
                    // selector borrow(address,uint256,uint16,address)
                    mstore(ptr, 0x1d5d723700000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _underlying)
                    mstore(add(ptr, 0x24), _amount)
                    mstore(add(ptr, 0x44), 0x0)
                    mstore(add(ptr, 0x64), _from)
                    // call pool
                    if iszero(call(gas(), YLDR, 0x0, ptr, 0x84, 0x0, 0x0)) {
                        returndatacopy(0x0, 0x0, returndatasize())
                        revert(0x0, returndatasize())
                    }
                }
                default {
                    let pool
                    switch _lenderId
                    case 0 {
                        pool := AAVE_V3
                    }
                    case 25 {
                        pool := AAVE_V2
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
            default {
                let cometPool
                switch _lenderId
                case 50 {
                    cometPool := COMET_USDC
                }
                case 51 {
                    cometPool := COMET_USDT
                }
                // default: load comet from storage
                // if it is not provided directly
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    cometPool := sload(keccak256(0x0, 0x40))
                    if iszero(cometPool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // selector withdrawFrom(address,address,address,uint256)
                mstore(ptr, 0x2644131800000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _from)
                mstore(add(ptr, 0x24), _to)
                mstore(add(ptr, 0x44), _underlying)
                mstore(add(ptr, 0x64), _amount)
                // call pool
                if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
        }
    }

    /// @notice Deposit to lender given user address and lender Id from cache
    function _deposit(address _underlying, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, 50)
            case 1 {
                switch lt(_lenderId, 25)
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
                    case 0 {
                        pool := AAVE_V3
                    }
                    case 1 {
                        pool := YLDR
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
                case 0 {
                    let pool
                    switch _lenderId
                    case 25 {
                        pool := AAVE_V2
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
                    // selector deposit(address,uint256,address,uint16)
                    mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _underlying)
                    mstore(add(ptr, 0x24), _amount)
                    mstore(add(ptr, 0x44), _to)
                    mstore(add(ptr, 0x64), 0x0)
                    // call pool
                    if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                        returndatacopy(0x0, 0x0, returndatasize())
                        revert(0x0, returndatasize())
                    }
                }
            }
            default {
                let cometPool
                switch _lenderId
                case 50 {
                    cometPool := COMET_USDC
                }
                case 51 {
                    cometPool := COMET_USDT
                }
                // default: load comet from storage
                // if it is not provided directly
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    cometPool := sload(keccak256(0x0, 0x40))
                    if iszero(cometPool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }
                // selector supplyTo(address,address,uint256)
                mstore(ptr, 0x4232cd6300000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _to)
                mstore(add(ptr, 0x24), _underlying)
                mstore(add(ptr, 0x44), _amount)
                // call pool
                if iszero(call(gas(), cometPool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id from cache
    function _repay(address _underlying, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, 50)
            case 1 {
                // assign lending pool
                switch _lenderId
                case 1 {
                    // same as aave V3, just no mode
                    // selector repay(address,uint256,address)
                    mstore(ptr, 0x5ceae9c400000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _underlying)
                    mstore(add(ptr, 0x24), _amount)
                    mstore(add(ptr, 0x44), _to)
                    // call pool
                    if iszero(call(gas(), YLDR, 0x0, ptr, 0x64, 0x0, 0x0)) {
                        returndatacopy(0x0, 0x0, returndatasize())
                        revert(0x0, returndatasize())
                    }
                }
                default {
                    let pool
                    switch _lenderId
                    case 0 {
                        pool := AAVE_V3
                    }
                    case 25 {
                        pool := AAVE_V3
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
            }
            default {
                let cometPool
                switch _lenderId
                case 50 {
                    cometPool := COMET_USDC
                }
                case 51 {
                    cometPool := COMET_USDT
                }
                // default: load comet from storage
                // if it is not provided directly
                default {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    cometPool := sload(keccak256(0x0, 0x40))
                    if iszero(cometPool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
                    }
                }

                // selector supplyTo(address,address,uint256)
                mstore(ptr, 0x4232cd6300000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _to)
                mstore(add(ptr, 0x24), _underlying)
                mstore(add(ptr, 0x44), _amount)
                // call pool
                if iszero(call(gas(), cometPool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
        }
    }
}
