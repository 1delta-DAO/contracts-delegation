// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ComposerCommands} from "./enums/DeltaEnums.sol";
import {ExternalCall} from "./generic/ExternalCall.sol";
import {Transfers} from "./transfers/Transfers.sol";
import {ERC4646Operations} from "./ERC4646/ERC4646Operations.sol";
import {UniversalLending} from "./lending/UniversalLending.sol";
import {Permits} from "./permit/Permits.sol";
import {UniversalFlashLoan} from "./flashLoan/UniversalFlashLoan.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerLight is
    UniversalLending,
    UniversalFlashLoan,
    ERC4646Operations,
    Transfers,
    Permits,
    ExternalCall //
{
    /**
     * Batch-executes a series of operations
     * The calldata is loaded in assembly and therefore not referred to here
     */
    function deltaCompose(bytes calldata) external payable {
        uint256 length;
        assembly {
            // the length of the calldata is stored per abi encoding standards
            length := calldataload(0x24)
        }
        _deltaComposeInternal(
            msg.sender,
            0, // no injecteds on the external compose
            0,
            0x44, // the offset is cponstant
            length
        );
    }

    /**
     * Execute a set op packed operations
     * @param callerAddress the address of the EOA/contract that
     *                      initially triggered the `deltaCompose`
     * | op0 | data0 | op1 | data1 | ...
     * | 1   | ...   |  1  | ...   | ...
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
            if (operation == ComposerCommands.EXT_CALL) {
                currentOffset = _callExternal(currentOffset);
            } else if (operation == ComposerCommands.LENDING) {
                currentOffset = _lendingOperations(callerAddress, paramPull, paramPush, currentOffset);
            } else if (operation == ComposerCommands.TRANSFERS) {
                currentOffset = _transfers(currentOffset, callerAddress);
            } else if (operation == ComposerCommands.PERMIT) {
                currentOffset = _permit(currentOffset, callerAddress);
            } else if (operation == ComposerCommands.FLASH_LOAN) {
                currentOffset = _universalFlashLoan(currentOffset, callerAddress);
            } else if (operation == ComposerCommands.ERC4646) {
                currentOffset = _ERC4646Operations(currentOffset, callerAddress);
            } else {
                _invalidOperation();
            }
            // break criteria - we shifted to the end of the calldata
            if (currentOffset >= maxIndex) break;
        }
    }
}
