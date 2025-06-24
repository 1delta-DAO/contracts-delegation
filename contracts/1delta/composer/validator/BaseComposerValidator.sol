// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ComposerCommands} from "../enums/DeltaEnums.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

abstract contract BaseComposerValidator is DeltaErrors {
    struct ValidationResult {
        bool isValid;
        string errorMessage;
        uint256 failedAtOffset;
    }

    function validateComposerCalldata(bytes calldata) external view returns (ValidationResult memory result) {
        uint256 length;
        assembly {
            length := calldataload(0x24)
        }

        return _validateComposeInternal(0x44, length);
    }

    function _validateComposeInternal(uint256 currentOffset, uint256 calldataLength) internal view returns (ValidationResult memory result) {
        result.isValid = true;

        uint256 maxIndex;
        assembly {
            maxIndex := add(currentOffset, calldataLength)
        }

        while (true) {
            uint256 operation;
            assembly {
                operation := shr(248, calldataload(currentOffset))
                currentOffset := add(1, currentOffset)
            }

            (bool opValid, string memory opError, uint256 newOffset) = _validateOperation(operation, currentOffset);

            if (!opValid) {
                result.isValid = false;
                result.errorMessage = opError;
                result.failedAtOffset = currentOffset;
                return result;
            }

            currentOffset = newOffset;

            // break if we skipped over the calldata
            if (currentOffset >= maxIndex) break;
        }

        // revert if some excess is left
        if (currentOffset > maxIndex) {
            result.isValid = false;
            result.errorMessage = "Invalid calldata length - excess data";
            result.failedAtOffset = currentOffset;
        }
    }

    /**
     * @notice Validates a single operation
     * @param operation The operation code
     * @param currentOffset Current position in calldata
     * @return isValid Whether the operation is valid
     * @return errorMessage Error message if invalid
     * @return newOffset New offset after validation
     */
    function _validateOperation(
        uint256 operation,
        uint256 currentOffset
    )
        internal
        view
        returns (bool isValid, string memory errorMessage, uint256 newOffset)
    {
        if (operation < ComposerCommands.PERMIT) {
            if (operation == ComposerCommands.SWAPS) {
                return _validateSwap(currentOffset);
            } else if (operation == ComposerCommands.EXT_CALL) {
                return _validateExternalCall(currentOffset);
            } else if (operation == ComposerCommands.LENDING) {
                return _validateLendingOperations(currentOffset);
            } else if (operation == ComposerCommands.TRANSFERS) {
                return _validateTransfers(currentOffset);
            } else {
                return (false, "Invalid operation in first if statement", currentOffset);
            }
        } else {
            if (operation == ComposerCommands.PERMIT) {
                return _validatePermit(currentOffset);
            } else if (operation == ComposerCommands.FLASH_LOAN) {
                return _validateFlashLoan(currentOffset);
            } else if (operation == ComposerCommands.ERC4626) {
                return _validateERC4626Operations(currentOffset);
            } else if (operation == ComposerCommands.GEN_2025_SINGELTONS) {
                return _validateGen2025DexActions(currentOffset);
            } else {
                return (false, "Invalid operation in second if statement", currentOffset);
            }
        }
    }

    function _validateSwap(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateExternalCall(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateLendingOperations(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateTransfers(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validatePermit(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateFlashLoan(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateERC4626Operations(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);

    function _validateGen2025DexActions(uint256 currentOffset) internal view virtual returns (bool, string memory, uint256);
}
