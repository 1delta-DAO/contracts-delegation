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

    constructor() {
        _initializeLock();
    }

    /**
     * @dev Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    )
        external
        returns (bool)
    {
        // forward execution
        _forwardExecutionToCaller(params);

        return true;
    }

    /**
     * @dev Aave V2 flash loan callback
     */
    function executeOperation(address[] calldata, uint256[] calldata, uint256[] calldata, address, bytes calldata params) external returns (bool) {
        // forward execution
        _forwardExecutionToCaller(params);

        return true;
    }

    /**
     * @dev Balancer flash loan
     */
    function receiveFlashLoan(address[] calldata, uint256[] calldata, uint256[] calldata, bytes calldata params) external {
        // execute further operations
        _forwardExecutionToCaller(params);
    }

    /**
     * @dev BalancerV3 flash loan
     */
    function receiveFlashLoan(bytes calldata data) external {
        // we should call the balancer V3 vault to transfer the tokens to the module
        // then the data should start with the call to sendTo
        // the sendTo function call is sendTo(address,address,uint256), the length of the calldata is 100 (4+32+32+32),
        // the rest of the data will be later is used as the data for the flashloan callback
        (bool success, bytes memory result) = msg.sender.call(data[:100]);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        // execute further operations
        _forwardExecutionToCaller(data[100:]);
    }

    /**
     * @dev Uniswap V4 flash loan
     */
    function unlockCallback(bytes calldata data) external {
        // execute further operations
        _forwardExecutionToCaller(data);
    }

    /**
     * @dev Morpho flash loan
     */
    function onMorphoFlashLoan(uint256, bytes calldata params) external {
        // execute further operations
        _forwardExecutionToCaller(params);
    }

    /**
     * @dev Handle flashloan repay
     * @param data The calldata to be executed
     */
    function handleRepay(bytes calldata data) external onlyInExecution {
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
    /// @param data The calldata that will be passed as the data to flashloan execute function
    function flashLoan(address flashLoanProvider, bytes calldata data) external lockExecutionForCaller {
        if (!initialized[msg.sender]) revert NotInitialized();
        if (data.length == 0) {
            revert InvalidCall();
        }

        (bool success, bytes memory result) = flashLoanProvider.call(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function onInstall(bytes calldata) external onlyNotInExecution {
        if (initialized[msg.sender]) revert AlreadyInitialized();
        initialized[msg.sender] = true;
    }

    function onUninstall(bytes calldata) external onlyNotInExecution {
        if (!initialized[msg.sender]) revert NotInitialized();
        initialized[msg.sender] = false;
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == 2;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return initialized[smartAccount];
    }

    /**
     * @dev Internal function to execute the calldata on the caller
     */
    function _forwardExecutionToCaller(bytes calldata data) internal {
        (bool success, bytes memory result) = _getCallerWithLockCheck().call(abi.encodePacked(INexus.executeFromExecutor.selector, data));
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
