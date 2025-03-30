// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {BaseComposer} from "./BaseComposer.sol";
import {BaseSwapper} from "./swappers/BaseSwapper.sol";
import {Native} from "./transfers/Native.sol";
import {Transfers} from "./transfers/Transfers.sol";
import {FlashLoanCallbacks} from "./flashLoan/callbacks/FlashLoanCallbacks.sol";
import {SwapCallbacks} from "./swappers/callbacks/SwapCallbacks.sol";

/**
 * @title Chain-dependent Universal aggregator contract.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerLight is BaseComposer, FlashLoanCallbacks, SwapCallbacks, Native {
    // initialize with an immutable forwarder
    constructor(address _forwarder) BaseComposer(_forwarder) {}

    /**
     * Execute a set of packed operations
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush,
        uint256 currentOffset,
        uint256 _length //
    ) internal override(BaseComposer, FlashLoanCallbacks, SwapCallbacks) {
        return
            BaseComposer._deltaComposeInternal(
                callerAddress,
                paramPull,
                paramPush,
                currentOffset,
                _length //
            );
    }

    /** Overrides for hard-coded wnative address */

    function _wrap(uint256 currentOffset) internal override(Native, Transfers) returns (uint256) {
        return Native._wrap(currentOffset);
    }

    function _unwrap(uint256 currentOffset) internal override(Native, Transfers) returns (uint256) {
        return Native._unwrap(currentOffset);
    }

    function _wrapOrUnwrapSimple(uint256 amount, uint256 currentOffset) internal override(Native, BaseSwapper) returns (uint256, uint256) {
        return Native._wrapOrUnwrapSimple(amount, currentOffset);
    }
}
