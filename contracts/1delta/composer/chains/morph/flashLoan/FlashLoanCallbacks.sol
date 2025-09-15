// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks {
    //
    // override the compose
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
