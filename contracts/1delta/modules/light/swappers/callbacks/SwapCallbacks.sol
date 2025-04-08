// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {UniV4Callbacks} from "./UnoV4.sol";
import {UniV3Callbacks} from "./UnoV3.sol";
import {UniV2Callbacks} from "./UnoV2.sol";
import {DodoV2Callbacks} from "./DodoV2.sol";
import {BalancerV3Callbacks} from "./BalancerV3.sol";

/**
 * @title Swap Callback executor
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

    /**
     * Swap callbacks are taken in the fallback
     * We do this to have an easier time in validating similar callbacks
     * with separate selectors
     *
     * We identify the selector in the fallback and then map it to the DEX
     *
     * Note that each `_execute...` function returns (exits) when a callback is run.
     *
     * If it falls through all variations, it reverts at the end.
     */
    fallback() external {
        bytes32 selector;
        assembly {
            selector := and(
                0xffffffff00000000000000000000000000000000000000000000000000000000, // masks upper 4 bytes
                calldataload(0)
            )
        }
        _executeUniV3IfSelector(selector);
        _executeUniV2IfSelector(selector);
        _executeDodoV2IfSelector(selector);

        // we do not allow a fallthrough
        assembly {
            revert(0, 0)
        }
    }
}
