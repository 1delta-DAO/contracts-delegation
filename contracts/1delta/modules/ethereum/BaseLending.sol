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
    // errors
    error BadLender();

    // aave type lender pool addresses
    address internal constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant SPARK = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address internal constant ZEROLEND = 0x3BC3D34C32cc98bf098D832364Df8A222bBaB4c0;
    address internal constant AVALON = 0x8AD8528202b747ED4Ab802Fd6A297c0B3CaD1cD4;
    address internal constant RADIANT = 0xA950974f64aA33f27F6C5e017eEE93BF7588ED07;
    address internal constant UWU = 0x2409aF0251DCB89EE3Dee572629291f9B087c668;
    address internal constant YLDR = 0x6447c4390457CaD03Ec1BaA4254CEe1A3D9e1Bbd;

    // compound V3 addresses
    address internal constant COMET_USDC = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address internal constant COMET_USDT = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;
    address internal constant COMET_WETH = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;

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
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
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
                    pool := AVALON
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
                    rdsize := returndatasize()
                    returndatacopy(0x0, 0x0, rdsize)
                    revert(0x0, rdsize)
                }
            }
            case 0 {
                // Compound V3
                switch lt(_lenderId, 75)
                case 1 {
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
                // Venus market ids
                default {
                    // load collateral token for market
                    mstore(0, _underlying)
                    mstore8(0, _lenderId)
                    mstore(0x20, COLLATERAL_TOKENS_SLOT) // add pointer to slot
                    let collateralToken := sload(keccak256(0x0, 0x40)) // access element

                    // 1) CALCULTAE TRANSFER AMOUNT
                    // Store fnSig (=bytes4(abi.encodeWithSignature("exchangeRateCurrent()"))) at params
                    // - here we store 32 bytes : 4 bytes of fnSig and 28 bytes of RIGHT padding
                    mstore(
                        0x0,
                        0xbd6d894d00000000000000000000000000000000000000000000000000000000 // with padding
                    )
                    // call to collateralToken
                    // accrues interest. No real risk of failure.
                    pop(
                        call(
                            gas(),
                            collateralToken,
                            0x0,
                            0x0,
                            0x24,
                            0x0, // store back to ptr
                            0x20
                        )
                    )

                    // load the retrieved protocol share
                    let refAmount := mload(0x0)

                    // calculate collateral token amount, rounding up
                    let transferAmount := add(
                        div(
                            mul(_amount, 1000000000000000000), // multiply with 1e18
                            refAmount // divide by rate
                        ),
                        1
                    )
                    // FETCH BALANCE
                    // selector for balanceOf(address)
                    mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                    // add this address as parameter
                    mstore(0x4, _to)

                    // call to collateralToken
                    pop(staticcall(gas(), collateralToken, 0x0, 0x24, 0x0, 0x20))

                    // load the retrieved balance
                    refAmount := mload(0x0)

                    // floor to the balance
                    if gt(transferAmount, refAmount) {
                        transferAmount := refAmount
                    }

                    // 2) TRANSFER VTOKENS

                    // selector for transferFrom(address,address,uint256)
                    mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _to) // from user
                    mstore(add(ptr, 0x24), address()) // to this address
                    mstore(add(ptr, 0x44), transferAmount)

                    let success := call(gas(), collateralToken, 0, ptr, 0x64, ptr, 32)

                    if iszero(success) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    // 3) REDEEM
                    // selector for redeem(uint256)
                    mstore(0, 0xdb006a7500000000000000000000000000000000000000000000000000000000)
                    mstore(0x4, transferAmount)

                    if iszero(
                        call(
                            gas(),
                            collateralToken,
                            0x0,
                            0x0, // input = selector
                            0x24, // input selector + uint256
                            0x0, // output
                            0x0 // output size = zero
                        )
                    ) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    // transfer tokens only if the receiver is not this address
                    if xor(address(), _to) {
                        // 4) TRANSFER TO RECIPIENT
                        // selector for transfer(address,uint256)
                        mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x04), _to)
                        mstore(add(ptr, 0x24), _amount)

                        success := call(gas(), _underlying, 0, ptr, 0x44, ptr, 32)

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
                            returndatacopy(ptr, 0, rdsize)
                            revert(ptr, rdsize)
                        }
                    }
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
                default {
                    let pool
                    switch _lenderId
                    case 0 {
                        pool := AAVE_V3
                    }
                    case 25 {
                        pool := AVALON
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
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
            default {
                switch lt(_lenderId, 75)
                case 1 {
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
                // Venus
                default {
                    mstore(0, _underlying) // pad the lender number (agnostic to uint_x)
                    mstore8(0, _lenderId)
                    mstore(0x20, COLLATERAL_TOKENS_SLOT) // add pointer to slot
                    let collateralToken := sload(keccak256(0x0, 0x40)) // acces element
                    // selector for borrowBehlaf(address,uint256)
                    mstore(ptr, 0x856e5bb300000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), _from) // user
                    mstore(add(ptr, 0x24), _amount) // to this address
                    if iszero(
                        call(
                            gas(),
                            collateralToken,
                            0x0, // no ETH sent
                            ptr, // input selector
                            0x44, // input size = selector + address + uint256
                            ptr, // output
                            0x0 // output size = zero
                        )
                    ) {
                        returndatacopy(ptr, 0, returndatasize())
                        revert(ptr, returndatasize())
                    }
                    if xor(address(), _to) {
                        // 4) TRANSFER TO RECIPIENT
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
                            returndatacopy(ptr, 0, rdsize)
                            revert(ptr, rdsize)
                        }
                    }
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
                case 0 {
                    let pool
                    switch _lenderId
                    case 25 {
                        pool := AVALON
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
            }
            default {
                switch lt(_lenderId, 75)
                case 1 {
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
                default {
                    mstore(0, _underlying) // pad the lender number (agnostic to uint_x)
                    mstore8(0, _lenderId)
                    mstore(0x20, COLLATERAL_TOKENS_SLOT) // add pointer to slot
                    let collateralToken := sload(keccak256(0x0, 0x40)) // acces element

                    // 1) DEPOSIT

                    // selector for mint(uint256)
                    mstore(0x0, 0xa0712d6800000000000000000000000000000000000000000000000000000000)
                    mstore(0x4, _amount)

                    let success := call(
                        gas(),
                        collateralToken,
                        0x0,
                        0x0, // input = selector and data
                        0x24, // input size = 4 + 32
                        0x0, // output
                        0x0 // output size = zero
                    )

                    if iszero(success) {
                        returndatacopy(ptr, 0, returndatasize())
                        revert(ptr, returndatasize())
                    }

                    // transfer the collateral tokens

                    // 2) GET BALANCE OF COLLATERAL TOKEN

                    // selector for balanceOf(address)
                    mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                    // add this address as parameter
                    mstore(0x4, address())

                    // call to collateralToken
                    pop(staticcall(gas(), collateralToken, 0x0, 0x24, 0x0, 0x20))

                    // load the retrieved balance
                    let collateralTokenAmount := mload(0x0)

                    // transfer to receiver if needed
                    if xor(address(), _to) {
                        // 3) TRANSFER TOKENS TO RECEIVER
                        // selector for transfer(address,uint256)
                        mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                        mstore(add(ptr, 0x04), _to)
                        mstore(add(ptr, 0x24), collateralTokenAmount)

                        success := call(gas(), collateralToken, 0, ptr, 0x44, ptr, 32)

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
                            returndatacopy(ptr, 0, rdsize)
                            revert(ptr, rdsize)
                        }
                    }
                }
            }
        }
    }

    /// @notice Repay to lender given user address and lender Id from cache
    function _repay(address _underlying, address _to, uint256 _amount, uint256 mode, uint256 _lenderId) internal {
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
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
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
                    mstore(add(ptr, 0x44), mode)
                    mstore(add(ptr, 0x64), _to)
                    // call pool
                    if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                        let rdsize := returndatasize()
                        returndatacopy(0x0, 0x0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
            }
            default {
                switch lt(_lenderId, 75)
                case 1 {
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
                default {
                    // load collateral token
                    mstore(0x0, _underlying)
                    mstore8(0, _lenderId)
                    mstore(0x20, COLLATERAL_TOKENS_SLOT) // add pointer to slot
                    let collateralToken := sload(keccak256(0x0, 0x40)) // acces element

                    // selector for repayBorrowBehalf(address,uint256)
                    mstore(ptr, 0x2608f81800000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), _to) // user
                    mstore(add(ptr, 0x24), _amount) // to this address

                    if iszero(
                        call(
                            gas(),
                            collateralToken,
                            0x0,
                            ptr, // input = empty for fallback
                            0x44, // input size = selector + address + uint256
                            ptr, // output
                            0x0 // output size = zero
                        )
                    ) {
                        returndatacopy(0x0, 0, returndatasize())
                        revert(0x0, returndatasize())
                    }
                }
            }
        }
    }
}
