// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "./FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ExecutionLock} from "./common/ExecutionLock.sol";

contract FlashAccount is FlashAccountBase, ExecutionLock {
    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /// @notice Execute a flash loan
    /// @param flashLoanProvider The destination address
    /// @param data The calldata to execute
    function executeFlashLoan(address flashLoanProvider, bytes calldata data) public onlyAuthorized setInExecution {
        _call(flashLoanProvider, 0, data);
    }

    /**
     * @dev Explicit flash loan callback functions
     * All of them are locked through the execution lock to prevent access outside
     * of the `execute` functions
     */

    /**
     * Aave simple flash loan
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
     * Aave V2 flash loan callback
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * Balancer flash loan
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * BalancerV3 flash loan
     */
    function receiveFlashLoan(bytes calldata data) external requireInExecution {
        // execute further operations
        _decodeAndExecute(data);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * Internal function to decode batch calldata
     */
    function _decodeAndExecute(bytes calldata params) internal {
        (
            address[] memory dest, //
            uint256[] memory value,
            bytes[] memory func
        ) = abi.decode(params, (address[], uint256[], bytes[]));
        if (dest.length != func.length || dest.length != value.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }
}
