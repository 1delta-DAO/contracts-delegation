// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {UniV3Callbacks} from "./UnoV3.sol";
import {UniV2Callbacks} from "./UnoV2.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract SwapCallbacks is
    UniV2Callbacks,
    UniV3Callbacks //
{
    // override the compose
    function _deltaComposeInternal(
        address callerAddress,
        uint256 paramPull,
        uint256 paramPush,
        uint256 offset,
        uint256 length
    )
        internal
        virtual
        override(
            UniV2Callbacks,
            UniV3Callbacks //
        )
    {}
}
