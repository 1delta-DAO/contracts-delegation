// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IExecutor} from "./interfaces/IExecuter.sol";
import {ExecutionLock} from "./ExecutionLock.sol";
import {INexus} from "./interfaces/INexus.sol";
import {IUniswapV4PoolManager} from "./interfaces/external/IUniswapV4PoolManager.sol";
import {IBalancerV3Vault} from "./interfaces/external/IBalancerV3Vault.sol";
import "./utils/ModeLib.sol";
import {FlashDataLib} from "./utils/FlashDataLib.sol";

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
        uint256 amount,
        uint256,
        address initiator,
        bytes calldata params // user params
    )
        external
        returns (bool)
    {
        // validate if the initiator is the module
        if (initiator != address(this)) {
            revert InvalidCaller();
        }

        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        /// @dev basically the module should transfer the assets to the caller, then the caller can use these assets
        _transfer(asset, amount, caller);

        // forward executions to the caller
        _forwardExecutionToCaller(caller, params);

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
        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        // forward executions to the caller
        _forwardExecutionToCaller(caller, params);

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
        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        // forward executions to the caller
        _forwardExecutionToCaller(caller, params);

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
        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        // decode the asset and amount
        (address token, uint256 amount) = FlashDataLib.getAssetAndAmount(data);

        IBalancerV3Vault vault = IBalancerV3Vault(msg.sender);

        // execute the sendTo call, pulling funds from vault
        vault.sendTo(token, caller, amount);

        // execute further operations, forward to the caller who unlocked the module
        // skip address (20) and amount (32)
        _forwardExecutionToCaller(caller, data[52:]);

        // repay the flash loan
        _transfer(token, amount, msg.sender);

        // settle the flash loan
        vault.settle(token, amount);
    }

    /**
     * @dev Uniswap V4 flash loan
     */
    function unlockCallback(bytes calldata data) external {
        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        // decode the asset and amount
        (address currency, uint256 amount) = FlashDataLib.getAssetAndAmount(data);

        // pull funds from pool manager
        IUniswapV4PoolManager poolManager = IUniswapV4PoolManager(msg.sender);

        poolManager.take(currency, caller, amount);

        // execute further operations
        // skip address (20) and amount (32)
        _forwardExecutionToCaller(caller, data[52:]);

        // native case - no sync
        if (currency == address(0)) {
            poolManager.settle{value: amount}();
        } else {
            // erc20 case
            poolManager.sync(currency);
            // repay the flash loan
            _transfer(currency, amount, msg.sender);
            poolManager.settle();
        }
    }

    /**
     * @dev Morpho flash loan
     */
    function onMorphoFlashLoan(uint256, bytes calldata params) external {
        // validate if the module is locked and get the caller who locked the module
        address caller = _getCallerWithLockCheck();

        // decode address of the token
        address token = address(bytes20(params[:20]));

        // execute further operations
        _forwardExecutionToCaller(caller, params[20:]);

        // repay the flash loan
        if (!_approvals[token]) {
            _approve(token, type(uint256).max, msg.sender);
            _approvals[token] = true;
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
    function _forwardExecutionToCaller(address caller_, bytes calldata data) internal {
        (bool success, bytes memory result) = caller_.call(abi.encodePacked(INexus.executeFromExecutor.selector, data));
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
