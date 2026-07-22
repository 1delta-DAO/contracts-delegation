// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {AaveV3FlashLoanCallback} from "./callbacks/AaveV3Callback.sol";

/**
 * @title Flash loan callbacks - chain-specific
 * @author 1delta
 */
contract FlashLoanCallbacks is AaveV3FlashLoanCallback {
    function _deltaComposeInternal(
        address callerAddress,
        uint256 offset,
        uint256 length
    )
        internal
        virtual
        override(AaveV3FlashLoanCallback)
    {}
}
