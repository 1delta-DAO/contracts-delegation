// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {UniV4Callbacks} from "./callbacks/UniV4Callback.sol";

/**
 * @title Swap Callback executor
 * @author 1delta Labs AG
 */
contract SwapCallbacks is UniV4Callbacks {
    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for swap callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 offset,
        uint256 length
    )
        internal
        virtual
        override(UniV4Callbacks)
    {}
}

