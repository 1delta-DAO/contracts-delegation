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
    mapping(address => bool) private _approvals;

    error AlreadyInitialized();
    error NotInitialized();
    error InvalidCall();
    error InvalidCaller();
    error UnknownFlashLoanCallback();

    constructor() {
        _initializeLock();
    }

    /**
     * @dev Aave simple flash loan
     */
    function executeOperation(
        address asset,
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

        // handle aave repay
        /// @dev the module should be pre-funded with the repay amount (flashloan amount + premium)
        /// the smart account could transfer the repay amount as its last encoded action in the data
        if (!_approvals[asset]) {
            _approve(asset, type(uint256).max, msg.sender);
            _approvals[asset] = true;
        }
        return true;
    }

    /**
     * @dev Aave V2 flash loan callback
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata params
    )
        external
        returns (bool)
    {
        // forward execution
        _forwardExecutionToCaller(params);

        // handle aave repay
        for (uint256 i = 0; i < assets.length; i++) {
            if (!_approvals[assets[i]]) {
                _approve(assets[i], type(uint256).max, msg.sender);
                _approvals[assets[i]] = true;
            }
        }
        return true;
    }

    /**
     * @dev Balancer v2 flash loan
     */
    function receiveFlashLoan(address[] calldata tokens, uint256[] calldata amounts, uint256[] calldata feeAmounts, bytes calldata params) external {
        // execute further operations
        _forwardExecutionToCaller(params);

        // repay the flash loan
        for (uint256 i = 0; i < tokens.length; i++) {
            _transfer(tokens[i], amounts[i] + feeAmounts[i], msg.sender);
        }
    }

    /**
     * @dev Balancer V3 flash loan implementation
     *
     * The data parameter contains:
     * 1. First 100 bytes:
     *    - 4 bytes: sendTo selector (transferring tokens to module)
     *    - 96 bytes: sendTo arguments (address recipient, address token, uint256 amount)
     *    - n bytes: what should be executed after the module received the funds
     * 2. Remaining bytes:
     *    - Used as callback data for the flash loan execution
     */
    function receiveFlashLoan(bytes calldata data) external {
        // decode the sendTo call
        (address recipient, address token, uint256 amount) = abi.decode(data[4:100], (address, address, uint256));
        if (recipient != address(this)) {
            revert InvalidCaller();
        }
        // execute the sendTo call
        (bool success, bytes memory result) = msg.sender.call(data[:100]);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        // execute further operations, forward to the caller who unlocked the module
        _forwardExecutionToCaller(data[100:]);

        // repay the flash loan
        _transfer(token, amount, msg.sender);

        // settle the flash loan
        (success, result) = msg.sender.call(abi.encodeWithSignature("settle(address,uint256)", token, amount));
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
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
        // decode address of the token
        address token = abi.decode(params[:20], (address));

        // execute further operations
        _forwardExecutionToCaller(params[20:]);

        // repay the flash loan
        if (!_approvals[token]) {
            _approve(token, type(uint256).max, msg.sender);
            _approvals[token] = true;
        }
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

    function _approve(address asset, uint256 amount, address to) internal {
        (bool success, bytes memory result) = asset.call(abi.encodeWithSignature("approve(address,uint256)", to, amount));
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function _transfer(address asset, uint256 amount, address to) internal {
        (bool success, bytes memory result) = asset.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
