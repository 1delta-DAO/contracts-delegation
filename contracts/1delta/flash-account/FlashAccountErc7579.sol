// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "./interfaces/IExecuter.sol";
import {ExecutionLock} from "./ExecutionLock.sol";
import {INexus} from "./interfaces/INexus.sol";
import "./utils/ModeLib.sol";

/// @title FlashAccountErc7579
/// @notice A module that allows a smart account to handle flash loan callbacks
/// @dev This module is compatible with the ERC-7579 standard
contract FlashAccountErc7579 is ExecutionLock, IExecutor {
    mapping(address => bool) public initialized;

    error AlreadyInitialized();
    error NotInitialized();
    error InvalidCall();
    error UnknownFlashLoanCallback();

    /**
     * @dev Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * @dev Aave V2 flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * @dev Balancer flash loan
     */
    function receiveFlashLoan(address[] calldata, uint256[] calldata, uint256[] calldata, bytes calldata params)
        external
        requireInExecution
    {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * @dev BalancerV3 flash loan
     */
    function receiveFlashLoan(bytes calldata data) external requireInExecution {
        // execute further operations
        _decodeAndExecute(data);
    }

    /**
     * @dev Morpho flash loan
     */
    function onMorphoFlashLoan(uint256, bytes calldata params) external requireInExecution {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * @dev Handle flashloan repay
     * @param data The calldata to be executed
     */
    function handleRepay(bytes calldata data) external requireInExecution {
        (address dest, bytes memory call) = abi.decode(data, (address, bytes));
        (bool success, bytes memory result) = dest.call(call);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /// @notice Execute a flash loan
    /// @param flashLoanProvider The flashloan provider address
    /// @param dataOffset The offset of the calldata that indicates the start of the flashloan calldata
    /// @param data The calldata that will be passed as the data to flashloan execute function
    function flashLoan(address flashLoanProvider, uint256 dataOffset, bytes calldata data) external setInExecution {
        if (!initialized[msg.sender]) revert NotInitialized();
        if (data.length == 0 || dataOffset <= 4) {
            // the dataOffset must be greater than 4 because the first 4 bytes are the selector
            revert InvalidCall();
        }

        /// @dev inject msg.sender into the calldata of flashloan request
        // Create a new memory buffer with extra space for msg.sender (20 bytes)
        bytes memory memData = new bytes(data.length + 20);

        assembly {
            // Get the pointer to the data area (after the length prefix)
            let memPtr := add(memData, 32)

            // Copy the original data up to the params offset position
            calldatacopy(
                memPtr, // destination
                data.offset, // source
                dataOffset // length to copy
            )

            // Read the params offset from the original data
            let paramsOffsetPos := add(data.offset, dataOffset)
            let paramsOffset := calldataload(paramsOffsetPos)

            // Calculate where the params data starts in the original calldata
            let paramsDataPos := add(data.offset, add(4, paramsOffset)) // +4 to skip selector

            // Read the params length
            let paramsLength := calldataload(paramsDataPos)

            // Store the updated params offset
            mstore(add(memPtr, dataOffset), paramsOffset)

            // Calculate where the params data will be in our new buffer
            let newParamsDataPtr := add(memPtr, add(4, paramsOffset)) // +4 to skip selector

            // Write the updated params length (original + 20 bytes for address)
            mstore(newParamsDataPtr, add(paramsLength, 20))

            // Write the msg.sender at the beginning of the params data
            mstore(add(newParamsDataPtr, 32), shl(96, caller()))

            // Copy the original params data after the msg.sender
            calldatacopy(
                add(newParamsDataPtr, 52), // destination: after length (32) + address (20)
                add(paramsDataPos, 32), // source: after length
                paramsLength // length to copy
            )

            // Copy any remaining data after the params
            let remainingDataPos := add(add(paramsDataPos, 32), paramsLength)
            let remainingDataLength := sub(add(data.offset, data.length), remainingDataPos)
            let newRemainingDataPos := add(add(newParamsDataPtr, 52), paramsLength)

            if gt(remainingDataLength, 0) {
                calldatacopy(
                    newRemainingDataPos, // destination
                    remainingDataPos, // source
                    remainingDataLength // length
                )
            }

            // Set the total length of our modified data
            mstore(memData, add(data.length, 20))
        }

        (bool success, bytes memory result) = flashLoanProvider.call(memData);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function onInstall(bytes calldata data) external {
        if (initialized[msg.sender]) revert AlreadyInitialized();
        initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata data) external {
        if (!initialized[msg.sender]) revert NotInitialized();
        initialized[msg.sender] = false;
    }

    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == 2;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return initialized[smartAccount];
    }

    /**
     * @dev Internal function to decode batch calldata
     */
    function _decodeAndExecute(bytes calldata params) internal {
        // extract sender address and data
        address sender = address(uint160(uint256(bytes32(params[0:32])) >> 96));
        bytes memory data = params[52:];
        // execute, using batch mode
        INexus(sender).executeFromExecutor(ModeLib.encodeSimpleBatch(), data);
    }
}
