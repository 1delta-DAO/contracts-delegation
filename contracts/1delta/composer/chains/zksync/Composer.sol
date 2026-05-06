// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {BaseComposer} from "../../BaseComposer.sol";
import {FlashLoanCallbacks} from "./flashLoan/FlashLoanCallbacks.sol";
import {UniversalFlashLoan} from "./flashLoan/UniversalFlashLoan.sol";

/**
 * @title Chain-dependent Universal aggregator contract.
 * @author 1delta Labs AG
 */
contract OneDeltaComposerZkSync is BaseComposer, UniversalFlashLoan {
    function _deltaComposeInternal(
        address callerAddress,
        uint256 currentOffset,
        uint256 calldataLength //
    )
        internal
        override(BaseComposer, FlashLoanCallbacks)
    {
        return BaseComposer._deltaComposeInternal(
            callerAddress,
            currentOffset,
            calldataLength //
        );
    }

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
