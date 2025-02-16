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
    address internal constant WRAPPED_NATIVE = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Aave V3 style lender pool addresses
    address internal constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address internal constant AAVE_V3_PRIME = 0x4e033931ad43597d96D6bcc25c280717730B58B1;
    address internal constant AAVE_V3_ETHER_FI = 0x0AA97c284e98396202b6A04024F5E2c65026F3c0;

    address internal constant SPARK = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;

    address internal constant ZEROLEND_STABLECOINS_RWA = 0xD3a4DA66EC15a001466F324FA08037f3272BDbE8;
    address internal constant ZEROLEND_BTC_LRTS = 0xCD2b31071119D7eA449a9D211AC8eBF7Ee97F987;
    address internal constant ZEROLEND_ETH_LRTS = 0x3BC3D34C32cc98bf098D832364Df8A222bBaB4c0;

    address internal constant KINZA = 0xeA14474946C59Dee1F103aD517132B3F19Cef1bE;

    address internal constant AVALON_SOLV_BTC = 0xCfe357D2dE5aa5dAB5fEf255c911D150d0246423;
    address internal constant AVALON_SWELL_BTC = 0xE0E468687703dD02BEFfB0BE13cFB109529F38e0;
    address internal constant AVALON_PUMP_BTC = 0x1c8091b280650aFc454939450699ECAA67C902d9;
    address internal constant AVALON_EBTC_LBTC = 0xCfe357D2dE5aa5dAB5fEf255c911D150d0246423;

    // no Aave v2s

    // Compound V3 addresses
    address internal constant COMET_USDT = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840;
    address internal constant COMET_USDC = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address internal constant COMET_WETH = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;
    address internal constant COMET_WSTETH = 0x3D0bb1ccaB520A66e607822fC55BC921738fAFE3;
    address internal constant COMET_USDS = 0x5D409e56D886231aDAf00c8775665AD0f9897b56;

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
                case 0 {
                    pool := AAVE_V3
                }
                case 1 {
                    pool := AAVE_V3_PRIME
                }
                case 2 {
                    pool := AAVE_V3_ETHER_FI
                }
                default {
                    switch lt(_lenderId, 200) // Check the hundred's place to categorize lenders
                    case 1 {
                        // AVALON group
                        switch _lenderId
                        case 100 {
                            pool := AVALON_SOLV_BTC
                        }
                        case 101 {
                            pool := AVALON_SWELL_BTC
                        }
                        case 102 {
                            pool := AVALON_PUMP_BTC
                        }
                        case 103 {
                            pool := AVALON_EBTC_LBTC
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
                    }
                    default {
                        // ZEROLEND group
                        switch _lenderId
                        case 200 {
                            pool := SPARK
                        }
                        case 210 {
                            pool := ZEROLEND_STABLECOINS_RWA
                        }
                        case 211 {
                            pool := ZEROLEND_BTC_LRTS
                        }
                        case 212 {
                            pool := ZEROLEND_ETH_LRTS
                        }
                        case 250 {
                            pool := KINZA
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
                    }
                }
                // call pool
                if iszero(call(gas(), pool, 0x0, ptr, 0x64, 0x0, 0x0)) {
                    returndatacopy(0x0, 0x0, returndatasize())
                    revert(0x0, returndatasize())
                }
            }
            default {
                switch lt(_lenderId, MAX_ID_COMPOUND_V3)
                case 1 {
                    let cometPool
                    switch _lenderId
                    case 2000 {
                        cometPool := COMET_USDC
                    }
                    case 2001 {
                        cometPool := COMET_WETH
                    }
                    case 2002 {
                        cometPool := COMET_USDT
                    }
                    case 2003 {
                        cometPool := COMET_WSTETH
                    }
                    case 2004 {
                        cometPool := COMET_USDS
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
                default {
                    // load collateral token for market
                    mstore(0x0, or(shl(240, _lenderId), _underlying))
                    mstore(0x20, COLLATERAL_TOKENS_SLOT)
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
                    mstore(0x0, ERC20_BALANCE_OF)
                    // add _from address as parameter
                    mstore(0x4, _from)

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
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), _from) // from user
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
                        mstore(ptr, ERC20_TRANSFER)
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

    /// @notice Borrow from lender lastgiven user address and lender Id
    function _borrow(address _underlying, address _from, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
                let pool
                switch _lenderId
                case 0 {
                    pool := AAVE_V3
                }
                case 1 {
                    pool := AAVE_V3_PRIME
                }
                case 2 {
                    pool := AAVE_V3_ETHER_FI
                }
                default {
                    switch lt(_lenderId, 200) // Check the hundred's place to categorize lenders
                    case 1 {
                        // AVALON group
                        switch _lenderId
                        case 100 {
                            pool := AVALON_SOLV_BTC
                        }
                        case 101 {
                            pool := AVALON_SWELL_BTC
                        }
                        case 102 {
                            pool := AVALON_PUMP_BTC
                        }
                        case 103 {
                            pool := AVALON_EBTC_LBTC
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
                    }
                    default {
                        // ZEROLEND group
                        switch _lenderId
                        case 200 {
                            pool := SPARK
                        }
                        case 210 {
                            pool := ZEROLEND_STABLECOINS_RWA
                        }
                        case 211 {
                            pool := ZEROLEND_BTC_LRTS
                        }
                        case 212 {
                            pool := ZEROLEND_ETH_LRTS
                        }
                        case 250 {
                            pool := KINZA
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
            default {
                switch lt(_lenderId, MAX_ID_COMPOUND_V3)
                case 1 {
                    let cometPool
                    switch _lenderId
                    case 2000 {
                        cometPool := COMET_USDC
                    }
                    case 2001 {
                        cometPool := COMET_WETH
                    }
                    case 2002 {
                        cometPool := COMET_USDT
                    }
                    case 2003 {
                        cometPool := COMET_WSTETH
                    }
                    case 2004 {
                        cometPool := COMET_USDS
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
                default {
                    mstore(0x0, or(shl(240, _lenderId), _underlying))
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
                            returndatacopy(ptr, 0, rdsize)
                            revert(ptr, rdsize)
                        }
                    }
                }
            }
        }
    }

    /// @notice Deposit to lender lastgiven user address and lender Id
    function _deposit(address _underlying, address _to, uint256 _amount, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
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
                    case 0 {
                        pool := AAVE_V3
                    }
                    case 1 {
                        pool := AAVE_V3_PRIME
                    }
                    case 2 {
                        pool := AAVE_V3_ETHER_FI
                    }
                    default {
                        switch lt(_lenderId, 200) // Check the hundred's place to categorize lenders
                        case 1 {
                            // AVALON group
                            switch _lenderId
                            case 100 {
                                pool := AVALON_SOLV_BTC
                            }
                            case 101 {
                                pool := AVALON_SWELL_BTC
                            }
                            case 102 {
                                pool := AVALON_PUMP_BTC
                            }
                            case 103 {
                                pool := AVALON_EBTC_LBTC
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
                        }
                        default {
                            // ZEROLEND group
                            switch _lenderId
                            case 200 {
                                pool := SPARK
                            }
                            case 210 {
                                pool := ZEROLEND_STABLECOINS_RWA
                            }
                            case 211 {
                                pool := ZEROLEND_BTC_LRTS
                            }
                            case 212 {
                                pool := ZEROLEND_ETH_LRTS
                            }
                            case 250 {
                                pool := KINZA
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
                        }
                    }
                    // call pool
                    if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                        returndatacopy(0x0, 0x0, returndatasize())
                        revert(0x0, returndatasize())
                    }
                }
                case 0 {
                    mstore(0x0, _lenderId)
                    mstore(0x20, LENDING_POOL_SLOT)
                    let pool := sload(keccak256(0x0, 0x40))
                    if iszero(pool) {
                        mstore(0, BAD_LENDER)
                        revert(0, 0x4)
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
                switch lt(_lenderId, MAX_ID_COMPOUND_V3)
                case 1 {
                    let cometPool
                    switch _lenderId
                    case 2000 {
                        cometPool := COMET_USDC
                    }
                    case 2001 {
                        cometPool := COMET_WETH
                    }
                    case 2002 {
                        cometPool := COMET_USDT
                    }
                    case 2003 {
                        cometPool := COMET_WSTETH
                    }
                    case 2004 {
                        cometPool := COMET_USDS
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
                    mstore(0x0, or(shl(240, _lenderId), _underlying))
                    mstore(0x20, COLLATERAL_TOKENS_SLOT) // add pointer to slot
                    let collateralToken := sload(keccak256(0x0, 0x40)) // acces element

                    // selector for mintBehalf(address,uint256)
                    mstore(ptr, 0x23323e0300000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), _to)
                    mstore(add(ptr, 0x24), _amount)

                    let success := call(
                        gas(),
                        collateralToken,
                        0x0,
                        ptr, // input = selector and data
                        0x44, // input size = 4 + 64
                        0x0, // output
                        0x0 // output size = zero
                    )

                    if iszero(success) {
                        returndatacopy(ptr, 0, returndatasize())
                        revert(ptr, returndatasize())
                    }
                }
            }
        }
    }

    /// @notice Repay to lender lastgiven user address and lender Id
    function _repay(address _underlying, address _to, uint256 _amount, uint256 _mode, uint256 _lenderId) internal {
        assembly {
            let ptr := mload(0x40)
            switch lt(_lenderId, MAX_ID_AAVE_V2)
            case 1 {
                let pool
                switch _lenderId
                case 0 {
                    pool := AAVE_V3
                }
                case 1 {
                    pool := AAVE_V3_PRIME
                }
                case 2 {
                    pool := AAVE_V3_ETHER_FI
                }
                default {
                    switch lt(_lenderId, 200) // Check the hundred's place to categorize lenders
                    case 1 {
                        // AVALON group
                        switch _lenderId
                        case 100 {
                            pool := AVALON_SOLV_BTC
                        }
                        case 101 {
                            pool := AVALON_SWELL_BTC
                        }
                        case 102 {
                            pool := AVALON_PUMP_BTC
                        }
                        case 103 {
                            pool := AVALON_EBTC_LBTC
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
                    }
                    default {
                        // ZEROLEND group
                        switch _lenderId
                        case 200 {
                            pool := SPARK
                        }
                        case 210 {
                            pool := ZEROLEND_STABLECOINS_RWA
                        }
                        case 211 {
                            pool := ZEROLEND_BTC_LRTS
                        }
                        case 212 {
                            pool := ZEROLEND_ETH_LRTS
                        }
                        case 250 {
                            pool := KINZA
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
                switch lt(_lenderId, MAX_ID_COMPOUND_V3)
                case 1 {
                    let cometPool
                    switch _lenderId
                    case 2000 {
                        cometPool := COMET_USDC
                    }
                    case 2001 {
                        cometPool := COMET_WETH
                    }
                    case 2002 {
                        cometPool := COMET_USDT
                    }
                    case 2003 {
                        cometPool := COMET_WSTETH
                    }
                    case 2004 {
                        cometPool := COMET_USDS
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
                    mstore(0x0, or(shl(240, _lenderId), _underlying))
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
