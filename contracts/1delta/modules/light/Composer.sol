// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Commands} from "../shared/Commands.sol";
import {UniversalLending} from "./lending/UniversalLending.sol";
import {ERC4646Transfers} from "./ERC4646Transfers.sol";
import {PermitUtils} from "../shared/permit/PermitUtils.sol";
import {DeltaErrors} from "../shared/errors/Errors.sol";

// import {console} from "forge-std/console.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerLight is ERC4646Transfers, UniversalLending, PermitUtils, DeltaErrors {
    // wNative
    address internal constant WRAPPED_NATIVE = 0x4200000000000000000000000000000000000006;

    // Balancer V2 vault
    address internal constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // Aave V3 style lender pool addresses
    address internal constant AAVE_V3 = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address internal constant AVALON = 0x6374a1F384737bcCCcD8fAE13064C18F7C8392e5;

    address internal constant ZEROLEND = 0x766f21277087E18967c1b10bF602d8Fe56d0c671;

    // Aave v2s
    address internal constant GRANARY = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;

    uint256 internal constant _PRE_PARAM = 1 << 253;

    /**
     * Batch-executes a series of operations
     * @param data compressed instruction calldata
     */
    function deltaCompose(bytes calldata data) external payable {
        uint length;
        assembly {
            length := data.length
        }
        _deltaComposeInternal(msg.sender, 0, 0, 68, length);
    }

    /**
     * Execute a set op packed operations
     * @param callerAddress the address of the EOA/contract that
     *                      initially triggered the `deltaCompose`
     * | op0 | length0 | data0 | op1 | length1 | ...
     * | 1   |    16   | ...   |  1  |    16   | ...
     */
    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint currentOffset, uint _length) internal {
        // data loop paramters
        uint256 maxIndex;
        assembly {
            maxIndex := add(currentOffset, _length)
        }

        ////////////////////////////////////////////////////
        // Progressively loop through the calldata
        // The first byte defines the operation
        // From there on, we read the data based on the
        // what the operation expects, e.g. read the next 32 bytes as uint256.
        //
        // `currentOffset` represents the current byte at which we
        //            are in the calldata
        // `maxIndex` is used as break criteria, this means that if
        //            currentOffset >= maxIndex, we iterated through
        //            the entire calldata.
        ////////////////////////////////////////////////////
        while (true) {
            uint256 operation;
            // fetch op metadata
            assembly {
                operation := shr(248, calldataload(currentOffset)) // last byte
                // we increment the current offset to skip the operation
                currentOffset := add(1, currentOffset)
            }
            if (operation < 0x10) {
                if (operation == Commands.EXTERNAL_CALL) {
                    ////////////////////////////////////////////////////
                    // Execute call to external contract. It consits of
                    // an approval target and call target.
                    // The combo of [approvalTarget, target] has to be whitelisted
                    // for calls. Those are exclusively swap aggregator contracts.
                    // An amount has to be supplied to check the allowance from
                    // this contract to target.
                    // NEVER whitelist a token as an attacker can call
                    // `transferFrom` on target
                    // Data layout:
                    //      bytes 0-20:                  token
                    //      bytes 20-40:                 target
                    //      bytes 40-54:                 amount
                    //      bytes 54-56:                 calldata length
                    //      bytes 56-(56+data length):   data
                    ////////////////////////////////////////////////////
                    assembly {
                        // get first three addresses
                        let token := shr(96, calldataload(currentOffset))
                        let target := shr(96, calldataload(add(currentOffset, 20)))

                        // get slot isValid[target]
                        mstore(0x0, target)
                        mstore(0x20, CALL_MANAGEMENT_VALID)
                        // validate target
                        if iszero(sload(keccak256(0x0, 0x40))) {
                            mstore(0, INVALID_TARGET)
                            revert(0, 0x4)
                        }
                        // get amount to check allowance
                        let amount := calldataload(add(currentOffset, 40))
                        let dataLength := and(UINT16_MASK, shr(128, amount))
                        amount := shr(144, amount) // shr will already mask correctly

                        // free memo ptr for populating the tx
                        let ptr := mload(0x40)

                        ////////////////////////////////////////////////////
                        // If the token is zero, we assume that it is a native
                        // transfer / swap and the approval check is skipped
                        ////////////////////////////////////////////////////
                        let nativeValue
                        switch iszero(token)
                        case 0 {
                            mstore(0x0, token)
                            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
                            mstore(0x20, keccak256(0x0, 0x40))
                            mstore(0x0, target)
                            let key := keccak256(0x0, 0x40)
                            // check if already approved
                            if iszero(sload(key)) {
                                ////////////////////////////////////////////////////
                                // Approve, at this point it is clear that the target
                                // is whitelisted
                                ////////////////////////////////////////////////////
                                // selector for approve(address,uint256)
                                mstore(ptr, ERC20_APPROVE)
                                mstore(add(ptr, 0x04), target)
                                mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

                                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                                    revert(0x0, 0x0)
                                }
                                sstore(key, 1)
                            }
                            nativeValue := 0
                        }
                        default {
                            nativeValue := amount
                        }
                        // increment offset to calldata start
                        currentOffset := add(56, currentOffset)
                        // copy calldata
                        calldatacopy(ptr, currentOffset, dataLength)
                        if iszero(
                            call(
                                gas(),
                                target,
                                nativeValue,
                                ptr, //
                                dataLength, // the length must be correct or the call will fail
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        // increment offset by data length
                        currentOffset := add(currentOffset, dataLength)
                    }
                }
            } else if (operation < 0x20) {
                if (operation == Commands.LENDING) {
                    currentOffset = lendingOperations(callerAddress, paramPull, paramPush, currentOffset);
                }
            } else if (operation < 0x30) {
                if (operation == Commands.TRANSFER_FROM) {
                    ////////////////////////////////////////////////////
                    // Transfers tokens froom caller to this address
                    // zero amount flags that the entire balance is sent
                    ////////////////////////////////////////////////////
                    assembly {
                        let underlying := shr(96, calldataload(currentOffset))
                        let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
                        let amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
                        // when entering 0 as amount, use the callwe balance
                        if iszero(amount) {
                            // selector for balanceOf(address)
                            mstore(0, ERC20_BALANCE_OF)
                            // add this address as parameter
                            mstore(0x04, callerAddress)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    underlying, // token
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20
                                )
                            )
                            // load the retrieved balance
                            amount := mload(0x0)
                        }
                        let ptr := mload(0x40) // free memory pointer

                        // selector for transferFrom(address,address,uint256)
                        mstore(ptr, ERC20_TRANSFER_FROM)
                        mstore(add(ptr, 0x04), callerAddress)
                        mstore(add(ptr, 0x24), receiver)
                        mstore(add(ptr, 0x44), amount)

                        let success := call(gas(), underlying, 0, ptr, 0x64, ptr, 32)

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
                        currentOffset := add(currentOffset, 54)
                    }
                } else if (operation == Commands.SWEEP) {
                    ////////////////////////////////////////////////////
                    // Transfers either token or native balance from this
                    // contract to receiver. Reverts if minAmount is
                    // less than the contract balance
                    // native asset is flagge via address(0) as parameter
                    // Data layout:
                    //      bytes 0-20:                  token (if zero, we assume native)
                    //      bytes 20-40:                 receiver
                    //      bytes 40-41:                 config
                    //                                      0: sweep balance and validate against amount
                    //                                         fetches the balance and checks balance >= amount
                    //                                      1: transfer amount to receiver, skip validation
                    //                                         forwards the ERC20 error if not enough balance
                    //      bytes 41-55:                 amount, either validation or transfer amount
                    ////////////////////////////////////////////////////
                    assembly {
                        let underlying := shr(96, calldataload(currentOffset))
                        // we skip shr by loading the address to the lower bytes
                        let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
                        // load so that amount is in the lower 14 bytes already
                        let providedAmount := calldataload(add(currentOffset, 23))
                        // load config
                        let config := and(UINT8_MASK, shr(112, providedAmount))
                        // mask amount
                        providedAmount := and(_UINT112_MASK, providedAmount)
                        // initialize transferAmount
                        let transferAmount

                        // zero address is native
                        switch iszero(underlying)
                        ////////////////////////////////////////////////////
                        // Transfer token
                        ////////////////////////////////////////////////////
                        case 0 {
                            // for config = 0, the amount is the balance and we
                            // check that the balance is larger tha the amount provided
                            switch config
                            case 0 {
                                // selector for balanceOf(address)
                                mstore(0, ERC20_BALANCE_OF)
                                // add this address as parameter
                                mstore(0x04, address())
                                // call to token
                                pop(
                                    staticcall(
                                        gas(),
                                        underlying,
                                        0x0,
                                        0x24,
                                        0x0,
                                        0x20 //
                                    )
                                )
                                // load the retrieved balance
                                transferAmount := mload(0x0)
                                // revert if balance is not enough
                                if lt(transferAmount, providedAmount) {
                                    mstore(0, SLIPPAGE)
                                    revert(0, 0x4)
                                }
                            }
                            default {
                                transferAmount := providedAmount
                            }
                            if gt(transferAmount, 0) {
                                let ptr := mload(0x40) // free memory pointer

                                // selector for transfer(address,uint256)
                                mstore(ptr, ERC20_TRANSFER)
                                mstore(add(ptr, 0x04), receiver)
                                mstore(add(ptr, 0x24), transferAmount)

                                let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)

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
                        ////////////////////////////////////////////////////
                        // Transfer native
                        ////////////////////////////////////////////////////
                        default {
                            switch config
                            case 0 {
                                transferAmount := selfbalance()
                                // revert if balance is not enough
                                if lt(transferAmount, providedAmount) {
                                    mstore(0, SLIPPAGE)
                                    revert(0, 0x4)
                                }
                            }
                            default {
                                transferAmount := providedAmount
                            }
                            if gt(transferAmount, 0) {
                                if iszero(
                                    call(
                                        gas(),
                                        receiver,
                                        providedAmount,
                                        0x0, // input = empty for fallback/receive
                                        0x0, // input size = zero
                                        0x0, // output = empty
                                        0x0 // output size = zero
                                    )
                                ) {
                                    mstore(0, NATIVE_TRANSFER)
                                    revert(0, 0x4) // revert when native transfer fails
                                }
                            }
                        }
                        currentOffset := add(currentOffset, 55)
                    }
                } else if (operation == Commands.WRAP_NATIVE) {
                    ////////////////////////////////////////////////////
                    // Wrap native, only uses amount as uint112
                    ////////////////////////////////////////////////////
                    assembly {
                        let amount := shr(144, calldataload(currentOffset))
                        if iszero(
                            call(
                                gas(),
                                WRAPPED_NATIVE,
                                amount, // ETH to deposit
                                0x0, // no input
                                0x0, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            // revert when native transfer fails
                            mstore(0, WRAP)
                            revert(0, 0x4)
                        }
                        currentOffset := add(currentOffset, 14)
                    }
                } else if (operation == Commands.UNWRAP_WNATIVE) {
                    ////////////////////////////////////////////////////
                    // Transfers either token or native balance from this
                    // contract to receiver. Reverts if minAmount is
                    // less than the contract balance
                    // native asset is flagge via address(0) as parameter
                    //      bytes 1-20:                 receiver
                    //      bytes 20-21:                 config
                    //                                      0: sweep balance and validate against amount
                    //                                         fetches the balance and checks balance >= amount
                    //                                      1: transfer amount to receiver, skip validation
                    //      bytes 21-35:                 amount, either validation or transfer amount
                    ////////////////////////////////////////////////////
                    assembly {
                        let receiver := shr(96, calldataload(currentOffset))
                        let providedAmount := calldataload(add(currentOffset, 3))
                        // load config
                        let config := and(UINT8_MASK, shr(112, providedAmount))
                        providedAmount := and(_UINT112_MASK, providedAmount)

                        let transferAmount
                        // validate if config is zero, otherwise skip
                        switch config
                        case 0 {
                            // selector for balanceOf(address)
                            mstore(0x0, ERC20_BALANCE_OF)
                            // add this address as parameter
                            mstore(0x4, address())

                            // call to underlying
                            pop(staticcall(gas(), WRAPPED_NATIVE, 0x0, 0x24, 0x0, 0x20))

                            transferAmount := mload(0x0)
                            if lt(transferAmount, providedAmount) {
                                mstore(0, SLIPPAGE)
                                revert(0, 0x4)
                            }
                        }
                        default {
                            transferAmount := providedAmount
                        }
                        if gt(transferAmount, 0) {
                            // selector for withdraw(uint256)
                            mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                            mstore(0x4, transferAmount)
                            // should not fail since WRAPPED_NATIVE is immutable
                            pop(
                                call(
                                    gas(),
                                    WRAPPED_NATIVE,
                                    0x0, // no ETH
                                    0x0, // start of data
                                    0x24, // input size = selector plus amount
                                    0x0, // output = empty
                                    0x0 // output size = zero
                                )
                            )
                            // transfer to receiver if different from this address
                            if xor(receiver, address()) {
                                // transfer native to receiver
                                if iszero(
                                    call(
                                        gas(),
                                        receiver,
                                        transferAmount,
                                        0x0, // input = empty for fallback
                                        0x0, // input size = zero
                                        0x0, // output = empty
                                        0x0 // output size = zero
                                    )
                                ) {
                                    // should only revert if receiver cannot receive native
                                    mstore(0, NATIVE_TRANSFER)
                                    revert(0, 0x4)
                                }
                            }
                        }
                        currentOffset := add(currentOffset, 35)
                    }
                } else if (operation == Commands.PERMIT2_TRANSFER_FROM) {
                    ////////////////////////////////////////////////////
                    // Transfers tokens froom caller to this address
                    // zero amount flags that the entire balance is sent
                    ////////////////////////////////////////////////////
                    assembly {
                        let underlying := shr(96, calldataload(currentOffset))
                        let receiver := and(ADDRESS_MASK, calldataload(add(currentOffset, 8)))
                        let amount := and(_UINT112_MASK, calldataload(add(currentOffset, 22)))
                        // when entering 0 as amount, use the callwe balance
                        if iszero(amount) {
                            // selector for balanceOf(address)
                            mstore(0, ERC20_BALANCE_OF)
                            // add this address as parameter
                            mstore(0x04, callerAddress)
                            // call to token
                            pop(
                                staticcall(
                                    gas(),
                                    underlying, // token
                                    0x0,
                                    0x24,
                                    0x0,
                                    0x20
                                )
                            )
                            // load the retrieved balance
                            amount := mload(0x0)
                        }

                        let ptr := mload(0x40)

                        mstore(ptr, PERMIT2_TRANSFER_FROM)
                        mstore(add(ptr, 0x04), callerAddress)
                        mstore(add(ptr, 0x24), receiver)
                        mstore(add(ptr, 0x44), amount)
                        mstore(add(ptr, 0x64), underlying)
                        if iszero(call(gas(), PERMIT2, 0, ptr, 0x84, 0x0, 0x0)) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        currentOffset := add(currentOffset, 54)
                    }
                } else if (operation == Commands.ERC4646) {
                    uint256 erc4646Operation;
                    assembly {
                        erc4646Operation := shr(248, calldataload(currentOffset))
                        currentOffset := add(currentOffset, 1)
                    }
                    /** ERC6464 deposit */
                    if (erc4646Operation == 0) {
                        currentOffset = _erc4646Deposit(currentOffset);
                    }
                    /** MetaMorpho withdraw */
                    else {
                        currentOffset = _erc4646Withdraw(currentOffset, callerAddress);
                    }
                }
            } else {
                if (operation == Commands.EXEC_PERMIT) {
                    ////////////////////////////////////////////////////
                    // Execute normal transfer permit (Dai, ERC20Permit, P2).
                    // The specific permit type is executed based
                    // on the permit length (credits to 1inch for the implementation)
                    // Data layout:
                    //      bytes 0-20:                  token
                    //      bytes 20-22:                 permit length
                    //      bytes 22-(22+permit length): permit data
                    ////////////////////////////////////////////////////
                    uint256 permitOffset;
                    uint256 permitLength;
                    address token;
                    assembly {
                        token := calldataload(currentOffset)
                        permitLength := and(UINT16_MASK, shr(80, token))
                        token := shr(96, token)
                        permitOffset := add(currentOffset, 22)
                        currentOffset := add(permitOffset, permitLength)
                    }
                    _tryPermit(token, permitOffset, permitLength, callerAddress);
                } else if (operation == Commands.EXEC_CREDIT_PERMIT) {
                    ////////////////////////////////////////////////////
                    // Execute credit delegation permit.
                    // The specific permit type is executed based
                    // on the permit length (credits to 1inch for the implementation)
                    // Data layout:
                    //      bytes 0-20:                  token
                    //      bytes 20-22:                 permit length
                    //      bytes 22-(22+permit length): permit data
                    ////////////////////////////////////////////////////
                    uint256 permitOffset;
                    uint256 permitLength;
                    address token;
                    assembly {
                        token := calldataload(currentOffset)
                        permitLength := and(UINT16_MASK, shr(80, token))
                        token := shr(96, token)
                        permitOffset := add(currentOffset, 22)
                        currentOffset := add(permitOffset, permitLength)
                    }
                    _tryCreditPermit(token, permitOffset, permitLength, callerAddress);
                } else if (operation == Commands.EXEC_COMPOUND_V3_PERMIT) {
                    ////////////////////////////////////////////////////
                    // Execute lending delegation based on Compound V3.
                    // Data layout:
                    //      bytes 0-20:                  comet address
                    //      bytes 20-22:                 permit length
                    //      bytes 22-(22+permit length): permit data
                    ////////////////////////////////////////////////////
                    uint256 permitOffset;
                    uint256 permitLength;
                    address comet;
                    assembly {
                        comet := calldataload(currentOffset)
                        permitLength := and(UINT16_MASK, shr(80, comet))
                        comet := shr(96, comet)
                        permitOffset := add(currentOffset, 22)
                        currentOffset := add(permitOffset, permitLength)
                    }
                    _tryCompoundV3Permit(comet, permitOffset, permitLength, callerAddress);
                } else if (operation == Commands.FLASH_LOAN) {
                    ////////////////////////////////////////////////////
                    // Execute single asset flash loan
                    // It will forward the calldata and current caller to
                    // the flash loan operator
                    // It has to be made sure that the contract holds the
                    // loaned tokens at the end of the execution
                    // Leftover assets should be swept in the bach step
                    // afterwards.
                    // Data layout:
                    //      bytes 0-1:                   source (uint8)
                    //      bytes 1-21:                  asset  (address)
                    //      bytes 21-35:                 amount (uint112)
                    //      bytes 35-37:                 params length (uint16)
                    //      bytes 37-(37+data length):   params (bytes) (to execute deltaCompose)
                    ////////////////////////////////////////////////////
                    assembly {
                        // first slice, including poolId, refCode, asset
                        let slice := calldataload(currentOffset)
                        let source := shr(248, slice) // already masks uint8 as last byte
                        // get token to loan
                        let token := and(ADDRESS_MASK, shr(88, slice))
                        // second calldata slice including amount annd params length
                        slice := calldataload(add(currentOffset, 21))
                        let amount := shr(144, slice) // shr will already mask uint112 here
                        // length of params
                        let calldataLength := and(UINT16_MASK, shr(128, slice))
                        switch source
                        case 254 {
                            // morpho should be the primary choice
                            let ptr := mload(0x40)

                            /**
                             * Approve MB beforehand for the flash amount
                             * Similar to Aave V3, they pull funds from the caller
                             */
                            mstore(0x0, token)
                            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
                            mstore(0x20, keccak256(0x0, 0x40))
                            mstore(0x0, MORPHO_BLUE)
                            let key := keccak256(0x0, 0x40)
                            // check if already approved
                            if iszero(sload(key)) {
                                // selector for approve(address,uint256)
                                mstore(ptr, ERC20_APPROVE)
                                mstore(add(ptr, 0x04), MORPHO_BLUE)
                                mstore(add(ptr, 0x24), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

                                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                                    revert(0x0, 0x0)
                                }
                                sstore(key, 1)
                            }

                            /** Prepare call */

                            // flashLoan(...)
                            mstore(ptr, 0xe0232b4200000000000000000000000000000000000000000000000000000000)
                            mstore(add(ptr, 4), token)
                            mstore(add(ptr, 36), amount)
                            mstore(add(ptr, 68), 0x60) // offset
                            mstore(add(ptr, 100), add(20, calldataLength)) // data length
                            mstore(add(ptr, 132), shl(96, callerAddress)) // caller
                            currentOffset := add(currentOffset, 37)
                            calldatacopy(add(ptr, 152), currentOffset, calldataLength) // calldata
                            if iszero(
                                call(
                                    gas(),
                                    MORPHO_BLUE,
                                    0x0,
                                    ptr,
                                    add(calldataLength, 152), // = 10 * 32 + 4
                                    0x0,
                                    0x0 //
                                )
                            ) {
                                let rdlen := returndatasize()
                                returndatacopy(0, 0, rdlen)
                                revert(0x0, rdlen)
                            }
                        }
                        case 0xff {
                            // balancer should be the secondary choice
                            let ptr := mload(0x40)
                            // flashLoan(...)
                            mstore(ptr, 0x5c38449e00000000000000000000000000000000000000000000000000000000)
                            mstore(add(ptr, 4), address())
                            mstore(add(ptr, 36), 0x80) // offset assets
                            mstore(add(ptr, 68), 0xc0) // offset amounts
                            mstore(add(ptr, 100), 0x100) // offset calldata
                            mstore(add(ptr, 132), 1) // length assets
                            mstore(add(ptr, 164), token) // asset
                            mstore(add(ptr, 196), 1) // length amounts
                            mstore(add(ptr, 228), amount) // amount
                            mstore(add(ptr, 260), add(21, calldataLength)) // length calldata
                            mstore8(add(ptr, 292), source) // source id
                            // caller at the beginning
                            mstore(add(ptr, 293), shl(96, callerAddress))
                            // caller at the beginning
                            currentOffset := add(currentOffset, 37)
                            calldatacopy(add(ptr, 313), currentOffset, calldataLength) // calldata
                            // set entry flag
                            sstore(FLASH_LOAN_GATEWAY_SLOT, 2)
                            if iszero(
                                call(
                                    gas(),
                                    BALANCER_V2_VAULT,
                                    0x0,
                                    ptr,
                                    add(calldataLength, 345), // = 10 * 32 + 4
                                    0x0,
                                    0x0 //
                                )
                            ) {
                                let rdlen := returndatasize()
                                returndatacopy(0, 0, rdlen)
                                revert(0x0, rdlen)
                            }
                            // unset entry flasg
                            sstore(FLASH_LOAN_GATEWAY_SLOT, 1)
                        }
                        default {
                            switch lt(source, 230)
                            case 1 {
                                let pool
                                switch source
                                case 0 {
                                    pool := AAVE_V3
                                }
                                case 100 {
                                    pool := AVALON
                                }
                                case 210 {
                                    pool := ZEROLEND
                                }
                                default {
                                    mstore(0, INVALID_FLASH_LOAN)
                                    revert(0, 0x4)
                                }

                                let ptr := mload(0x40)
                                // flashLoanSimple(...)
                                mstore(ptr, 0x42b0b77c00000000000000000000000000000000000000000000000000000000)
                                mstore(add(ptr, 4), address())
                                mstore(add(ptr, 36), token) // asset
                                mstore(add(ptr, 68), amount) // amount
                                mstore(add(ptr, 100), 0xa0) // offset calldata
                                mstore(add(ptr, 132), 0) // refCode
                                mstore(add(ptr, 164), add(21, calldataLength)) // length calldata
                                mstore8(add(ptr, 196), source) // source id
                                // caller at the beginning
                                mstore(add(ptr, 197), shl(96, callerAddress))
                                currentOffset := add(currentOffset, 37)
                                calldatacopy(add(ptr, 217), currentOffset, calldataLength) // calldata
                                if iszero(
                                    call(
                                        gas(),
                                        pool,
                                        0x0,
                                        ptr,
                                        add(calldataLength, 228), // = 7 * 32 + 4
                                        0x0,
                                        0x0 //
                                    )
                                ) {
                                    let rdlen := returndatasize()
                                    returndatacopy(0, 0, rdlen)
                                    revert(0x0, rdlen)
                                }
                            }
                            default {
                                let pool
                                switch source
                                case 240 {
                                    pool := GRANARY
                                }
                                // We revert on any other id
                                default {
                                    mstore(0, INVALID_FLASH_LOAN)
                                    revert(0, 0x4)
                                }
                                // call flash loan
                                let ptr := mload(0x40)
                                // flashLoan(...) (See Aave V2 ILendingPool)
                                mstore(ptr, 0xab9c4b5d00000000000000000000000000000000000000000000000000000000)
                                mstore(add(ptr, 4), address()) // receiver is this address
                                mstore(add(ptr, 36), 0x0e0) // offset assets
                                mstore(add(ptr, 68), 0x120) // offset amounts
                                mstore(add(ptr, 100), 0x160) // offset modes
                                mstore(add(ptr, 132), 0) // onBefhalfOf = 0
                                mstore(add(ptr, 164), 0x1a0) // offset calldata
                                mstore(add(ptr, 196), 0) // referral code = 0
                                mstore(add(ptr, 228), 1) // length assets
                                mstore(add(ptr, 260), token) // assets[0]
                                mstore(add(ptr, 292), 1) // length amounts
                                mstore(add(ptr, 324), amount) // amounts[0]
                                mstore(add(ptr, 356), 1) // length modes
                                mstore(add(ptr, 388), 0) // mode = 0
                                ////////////////////////////////////////////////////
                                // We attach [souceId | caller] as first 21 bytes
                                // to the params
                                ////////////////////////////////////////////////////
                                mstore(add(ptr, 420), add(21, calldataLength)) // length calldata (plus 1 + address)
                                mstore8(add(ptr, 452), source) // source id
                                // caller at the beginning
                                mstore(add(ptr, 453), shl(96, callerAddress))

                                // increment offset by the preceding bytes length
                                currentOffset := add(currentOffset, 37)
                                // copy the calldataslice for the params
                                calldatacopy(
                                    add(ptr, 473), // next slot
                                    currentOffset, // offset starts at 37, already incremented
                                    calldataLength // copy given length
                                ) // calldata
                                if iszero(
                                    call(
                                        gas(),
                                        pool,
                                        0x0,
                                        ptr,
                                        add(calldataLength, 473), // = 14 * 32 + 4 + 20 (caller)
                                        0x0,
                                        0x0 //
                                    )
                                ) {
                                    let rdlen := returndatasize()
                                    returndatacopy(0, 0, rdlen)
                                    revert(0x0, rdlen)
                                }
                            }
                        }
                        // increment offset
                        currentOffset := add(currentOffset, calldataLength)
                    }
                } else {
                    assembly {
                        mstore(0, INVALID_OPERATION)
                        revert(0, 0x4)
                    }
                }
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }

    /**
     * @dev Aave V2 style flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata, // we assume that the data is known to the caller in advance
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 240 {
                if xor(caller(), GRANARY) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V2 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
        return true;
    }

    /**
     * @dev Aave V3 style flash loan callback
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    ) external returns (bool) {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 0 {
                if xor(caller(), AAVE_V3) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            case 100 {
                if xor(caller(), AVALON) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            case 210 {
                if xor(caller(), ZEROLEND) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V3 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
        return true;
    }

    /**
     * @dev Balancer flash loan call
     * Gated via flash loan gateway flag to prevent calls from sources other than this contract
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // validate caller
            // - extract id from params
            let firstWord := calldataload(calldataOffset)
            // needs no uint8 masking as we shift 248 bits
            let source := shr(248, firstWord)

            // Validate the caller
            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the `initiator` paramter the caller of `flashLoan`
            switch source
            case 0xff {
                if xor(caller(), BALANCER_V2_VAULT) {
                    mstore(0, INVALID_FLASH_LOAN)
                    revert(0, 0x4)
                }
            }
            // We revert on any other id
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // check that the entry flag is
            if iszero(eq(2, sload(FLASH_LOAN_GATEWAY_SLOT))) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(88, firstWord))
            // shift / slice params
            calldataOffset := add(calldataOffset, 21)
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
    }

    /** Morpho blue callbacks */

    /// @dev Morpho Blue flash loan
    function onMorphoFlashLoan(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue supply callback
    function onMorphoSupply(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue repay callback
    function onMorphoRepay(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue supply collateral callback
    function onMorphoSupplyCollateral(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue is immutable and their flash loans are callbacks to msg.sender,
    /// Since it is universal batching and the same validation for all
    /// Morpho callbacks, we can use the same logic everywhere
    function _onMorphoCallback(bytes calldata params) internal {
        address origCaller;
        uint256 calldataOffset;
        uint256 calldataLength;
        assembly {
            calldataOffset := params.offset
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }

            // Validate the caller - MUST be morpho
            if xor(caller(), MORPHO_BLUE) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := and(ADDRESS_MASK, shr(96, calldataload(calldataOffset)))
            // shift / slice params
            calldataOffset := add(calldataOffset, 20)
            calldataLength := sub(calldataLength, 20)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, 0, 0, calldataOffset, calldataLength);
    }
}
