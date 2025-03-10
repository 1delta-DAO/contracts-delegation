// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {BaseComposer} from "./BaseComposer.sol";
import {FlashLoanCallbacks} from "./flashLoan/callbacks/FlashLoanCallbacks.sol";

/**
 * @title Chain-dependent Universal aggregator contract.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerLight is BaseComposer, FlashLoanCallbacks {
    /**
     * Execute a set op packed operations
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush,
        uint256 currentOffset,
        uint256 _length //
    ) internal override(BaseComposer, FlashLoanCallbacks) {
        return
            BaseComposer._deltaComposeInternal(
                callerAddress,
                paramPull,
                paramPush,
                currentOffset,
                _length //
            );
    }
}
