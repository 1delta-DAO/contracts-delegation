// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../shared/storage/Slots.sol";
import {ERC20Selectors} from "../shared/selectors/ERC20Selectors.sol";

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps multiple lender types.
 */
abstract contract BaseLending is Slots, ERC20Selectors {
    // errors
    error BadLender();

    // id thresholds
    uint256 internal constant MAX_ID_AAVE_V3 = 1000; // 0-1000
    uint256 internal constant MAX_ID_AAVE_V2 = 2000; // 1000-2000

    // wNative
    address internal constant WRAPPED_NATIVE = 0xA51894664A773981C6C112C43ce576f315d5b1B6;

    // lender pool addresses
    address internal constant HANA_POOL = 0x4aB85Bf9EA548410023b25a13031E91B4c4f3b91;
    address internal constant MERIDIAN_POOL = 0x1697A950a67d9040464287b88fCa6cb5FbEC09BA;
    address internal constant TAKOTAKO_POOL = 0x3A2Fd8a16030fFa8D66E47C3f1C0507c673C841e;

    address internal constant AVALON_POOL = 0xA7f1c55530B1651665C15d8104663B3f03E3386f;
    address internal constant AVALON_SOLV_BTC_POOL = 0x9dd29AA2BD662E6b569524ba00C55be39e7B00fB;
    address internal constant AVALON_USDA_POOL = 0xC1bFbF4E0AdCA79790bfa0A557E4080F05e2B438;

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

                /**
                 * PREPARE TRANSFER_FROM USER
                 */

                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), _from)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), _amount)

                let success := call(gas(), collateralToken, 0x0, ptr, 0x64, 0x0, 0x20)

                let rdsize := returndatasize()

                success :=
                    and(
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
                case 0 { pool := HANA_POOL }
                case 100 { pool := AVALON_POOL }
                case 101 { pool := AVALON_SOLV_BTC_POOL }
                case 150 { pool := AVALON_USDA_POOL }
                case 1000 { pool := MERIDIAN_POOL }
                case 1001 { pool := TAKOTAKO_POOL }
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
                    rdsize := returndatasize()
                    returndatacopy(0x0, 0x0, rdsize)
                    revert(0x0, rdsize)
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
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
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
                case 0 { pool := HANA_POOL }
                case 100 { pool := AVALON_POOL }
                case 101 { pool := AVALON_SOLV_BTC_POOL }
                case 150 { pool := AVALON_USDA_POOL }
                case 1000 { pool := MERIDIAN_POOL }
                case 1001 { pool := TAKOTAKO_POOL }
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
                    success :=
                        and(
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
                mstore(0, BAD_LENDER)
                revert(0, 0x4)
            }
        }
    }

    /// @notice Deposit to lender lastgiven user address and lender Id
    function _deposit(address _underlying, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            // aave v3s first
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
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
                    case 0 { pool := HANA_POOL }
                    case 100 { pool := AVALON_POOL }
                    case 101 { pool := AVALON_SOLV_BTC_POOL }
                    case 150 { pool := AVALON_USDA_POOL }
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
                    // selector deposit(address,uint256,address,uint16)
                    mstore(ptr, 0xe8eda9df00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _underlying)
                    mstore(add(ptr, 0x24), _amount)
                    mstore(add(ptr, 0x44), _to)
                    mstore(add(ptr, 0x64), 0x0)
                    let pool
                    // assign lending pool
                    switch _lenderId
                    case 1000 { pool := MERIDIAN_POOL }
                    case 1001 { pool := TAKOTAKO_POOL }
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
            }
            default {
                mstore(0, BAD_LENDER)
                revert(0, 0x4)
            }
        }
    }

    /// @notice Repay to lender lastgiven user address and lender Id
    function _repay(address _underlying, address _to, uint256 _amount, uint256 mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
                // selector repay(address,uint256,uint256,address)
                mstore(ptr, 0x573ade8100000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), _underlying)
                mstore(add(ptr, 0x24), _amount)
                mstore(add(ptr, 0x44), mode)
                mstore(add(ptr, 0x64), _to)
                let pool
                // assign lending pool
                switch _lenderId
                case 0 { pool := HANA_POOL }
                case 100 { pool := AVALON_POOL }
                case 101 { pool := AVALON_SOLV_BTC_POOL }
                case 150 { pool := AVALON_USDA_POOL }
                case 1000 { pool := MERIDIAN_POOL }
                case 1001 { pool := TAKOTAKO_POOL }
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
}
