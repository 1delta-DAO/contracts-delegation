// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {BaseComposer} from "../../BaseComposer.sol";
import {SwapCallbacks} from "./flashSwap/SwapCallbacks.sol";
import {FlashLoanCallbacks} from "./flashLoan/FlashLoanCallbacks.sol";
import {UniversalFlashLoan} from "./flashLoan/UniversalFlashLoan.sol";

/**
 * @title Chain-dependent Universal aggregator contract.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerSei is BaseComposer, UniversalFlashLoan, SwapCallbacks {
    /**
     * @notice Execute a set of packed operations
     * @param callerAddress Address of the original caller
     * @param currentOffset Current position in the calldata
     * @param calldataLength Length of remaining calldata
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 currentOffset,
        uint256 calldataLength //
    )
        internal
        override(BaseComposer, FlashLoanCallbacks, SwapCallbacks)
    {
        return BaseComposer._deltaComposeInternal(
            callerAddress,
            currentOffset,
            calldataLength //
        );
    }

    /**
     * @notice Executes universal flash loan operations
     * @dev Routes flash loan requests to appropriate provider
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the original caller
     * @return Updated calldata offset after processing
     */
    function _universalFlashLoan(
        uint256 currentOffset,
        address callerAddress
    )
        internal
        override(UniversalFlashLoan, BaseComposer)
        returns (uint256)
    {
        return UniversalFlashLoan._universalFlashLoan(
            currentOffset,
            callerAddress //
        );
    }
}
