
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {BaseComposer} from "../../BaseComposer.sol";
import {SwapCallbacks} from "./callbacks/flashSwap/SwapCallbacks.sol";
import {FlashLoanCallbacks} from "./callbacks/flashLoan/FlashLoanCallbacks.sol";

/**
 * @title Chain-dependent Universal aggregator contract.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerHemi is BaseComposer, FlashLoanCallbacks, SwapCallbacks {
    // initialize with an immutable forwarder
    constructor() BaseComposer() {}

    /**
     * Execute a set of packed operations
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 currentOffset,
        uint256 calldataLength //
    ) internal override(BaseComposer, FlashLoanCallbacks, SwapCallbacks) {
        return
            BaseComposer._deltaComposeInternal(
                callerAddress,
                currentOffset,
                calldataLength //
            );
    }
}

