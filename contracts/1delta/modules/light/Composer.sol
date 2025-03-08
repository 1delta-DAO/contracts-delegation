// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Commands} from "../shared/Commands.sol";
import {ExternalCall} from "./generic/ExternalCall.sol";
import {Transfers} from "./transfers/Transfers.sol";
import {Native} from "./transfers/Native.sol";
import {ERC4646Transfers} from "./transfers/ERC4646Transfers.sol";
import {UniversalLending} from "./lending/UniversalLending.sol";
import {UniversalFlashLoan} from "./flashLoan/UniversalFlashLoan.sol";
import {PermitUtils} from "../shared/permit/PermitUtils.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerLight is
    PermitUtils,
    UniversalLending,
    UniversalFlashLoan,
    ERC4646Transfers,
    Transfers,
    Native,
    ExternalCall //
{
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
    function _deltaComposeInternal(
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush,
        uint256 currentOffset,
        uint256 _length //
    ) internal override(UniversalFlashLoan) {
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
                    currentOffset = _callExternal(currentOffset);
                }
            } else if (operation < 0x20) {
                if (operation == Commands.LENDING) {
                    currentOffset = lendingOperations(callerAddress, paramPull, paramPush, currentOffset);
                }
            } else if (operation < 0x30) {
                if (operation == Commands.TRANSFER_FROM) {
                    currentOffset = _transferFrom(currentOffset, callerAddress);
                } else if (operation == Commands.SWEEP) {
                    currentOffset = _sweep(currentOffset);
                } else if (operation == Commands.WRAP_NATIVE) {
                    currentOffset = _wrap(currentOffset);
                } else if (operation == Commands.UNWRAP_WNATIVE) {
                    currentOffset = _unwrap(currentOffset);
                } else if (operation == Commands.PERMIT2_TRANSFER_FROM) {
                    currentOffset = _permit2TransferFrom(currentOffset, callerAddress);
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
                    currentOffset = _universalFlashLoan(currentOffset, callerAddress);
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
}
