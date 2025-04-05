// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {UniV4Callbacks} from "./UnoV4.sol";
import {UniV3Callbacks} from "./UnoV3.sol";
import {UniV2Callbacks} from "./UnoV2.sol";
import {DodoV2Callbacks} from "./DodoV2.sol";
import {BalancerV3Callbacks} from "./BalancerV3.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract SwapCallbacks is
    DodoV2Callbacks,
    BalancerV3Callbacks,
    UniV2Callbacks,
    UniV3Callbacks,
    UniV4Callbacks //
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
            DodoV2Callbacks,
            BalancerV3Callbacks,
            UniV2Callbacks,
            UniV3Callbacks,
            UniV4Callbacks //
        )
    {}
}
