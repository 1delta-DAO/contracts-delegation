// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IExecutor} from "nexus/contracts/interfaces/modules/IExecutor.sol";
import "nexus/contracts/lib/ModeLib.sol";
import {ExecutionLock} from "./ExecutionLock.sol";

interface INexus {
    function executeFromExecutor(ExecutionMode mode, bytes calldata executionCalldata)
        external
        payable
        returns (bytes[] memory returnData);
}

contract FlashAccountErc7579 is ExecutionLock, IExecutor {
    /**
     * FlashLoan callback signature selectors
     */
    bytes4 private constant AAVE_SIMPLE_SELECTOR = 0x1b11d0ff; // executeOperation(address,uint256,uint256,address,bytes)
    bytes4 private constant AAVE_SELECTOR = 0x920f5c84; // executeOperation(address[],uint256[],uint256[],address,bytes)
    bytes4 private constant BALANCER_SELECTOR = 0xf04f2707; // receiveFlashLoan(address[],uint256[],uint256[],bytes)
    bytes4 private constant BALANCER_V3_SELECTOR = 0x7b72d2ce; // receiveFlashLoan(bytes)
    bytes4 private constant MORPHO_SELECTOR = 0x31f57072; // onMorphoFlashLoan(uint256,bytes)

    error AlreadyInitialized();
    error NotInitialized();
    error InvalidCall();
    error UnknownFlashLoanCallback();

    mapping(address => bool) public initialized;

    constructor() {}

    fallback() external payable requireInExecution {
        if (msg.data.length < 24) revert InvalidCall();

        bytes4 selector = bytes4(msg.data[:4]);
        bytes calldata params;

        if (selector == AAVE_SIMPLE_SELECTOR) {
            params = msg.data[132:]; // 4 + 32*4 = 132 bytes offset
        } else if (selector == AAVE_SELECTOR) {
            uint256 arrLength = uint256(bytes32(msg.data[4:36])); // the length of the first array
            uint256 offset = 4 + 32 + arrLength * 96;
            params = msg.data[offset:];
        } else if (selector == BALANCER_SELECTOR) {
            uint256 bytesOffset = uint256(bytes32(msg.data[132:164])); // 4 + 32*4 = 132
            params = msg.data[4 + bytesOffset:];
        } else if (selector == BALANCER_V3_SELECTOR) {
            params = msg.data[4:];
        } else if (selector == MORPHO_SELECTOR) {
            params = msg.data[36:];
        } else {
            revert UnknownFlashLoanCallback();
        }

        // Handle the flash loan via the common handler
        _handleFlashLoanCallback(params);

        // Return true for Aave callbacks
        if (selector == AAVE_SIMPLE_SELECTOR || selector == AAVE_SELECTOR) {
            assembly {
                mstore(0, 1)
                return(0, 32)
            }
        }
    }

    /// @notice Execute a flash loan
    /// @param flashLoanProvider The destination address
    /// @param data The calldata to execute
    function flashLoan(address flashLoanProvider, bytes calldata data) external setInExecution {
        if (!initialized[msg.sender]) revert NotInitialized();
        if (data.length == 0) revert InvalidCall();
        bytes4 selector = bytes4(data[:4]);
        bytes memory params = data[4:];
        bytes memory dt = abi.encodePacked(selector, msg.sender, params);
        flashLoanProvider.call(dt);
    }

    function _handleFlashLoanCallback(bytes calldata data) internal {
        assembly {
            if lt(data.length, 52) {
                mstore(0, 0xae962d4e) // InvalidCall()
                revert(0, 4)
            }

            let sender := shr(96, calldataload(data.offset)) // sender address is the first 20 bytes

            mstore(0, sender)
            mstore(32, initialized.slot)
            let isInitialized := sload(keccak256(0, 64)) //check if the module is installed for the sender
            if iszero(isInitialized) {
                mstore(0, 0x87138d5c) // NotInitialized()
                revert(0, 4)
            }

            let mode := calldataload(add(data.offset, 20)) // the next 32 bytes is the mode
            let executionDataLength := sub(data.length, 52) // the rest of the data is the execution calldata

            let execPtr := mload(0x40)
            mstore(execPtr, 0xd691c964) // selector for executeFromExecutor(bytes32,bytes)
            mstore(add(4, execPtr), mode) // save the mode

            calldatacopy(
                add(execPtr, 36), // after the mode
                add(data.offset, 52), // after the sender and mode in the calldata
                executionDataLength // length of execution calldata
            )

            mstore(0x40, add(add(execPtr, 36), executionDataLength)) // update the free memory pointer

            let success := call(gas(), sender, 0, execPtr, add(36, executionDataLength), 0, 0)

            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
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
}
