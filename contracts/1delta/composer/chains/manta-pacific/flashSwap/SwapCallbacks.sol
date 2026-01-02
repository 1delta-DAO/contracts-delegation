// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {UniV3Callbacks, V3Callbacker} from "./callbacks/UniV3Callback.sol";
import {DodoV2Callbacks} from "./callbacks/DodoV2Callback.sol";

/**
 * @title Swap Callback executor
 * @author 1delta Labs AG
 */
contract SwapCallbacks is
    UniV3Callbacks,
    DodoV2Callbacks //
{
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
        override(
            V3Callbacker,
            DodoV2Callbacks //
        )
    {}

    /**
     * @notice Fallback function that handles swap callbacks
     * @dev Swap callbacks are taken in the fallback. We do this to have an easier time in validating similar callbacks with separate selectors.
     * We identify the selector in the fallback and then map it to the DEX.
     * Note that each "_execute..." function returns (exits) when a callback is run.
     * If it falls through all variations, it reverts at the end.
     */
    fallback() external {
        bytes32 selector;
        assembly {
            selector :=
                and(
                    0xffffffff00000000000000000000000000000000000000000000000000000000, // masks upper 4 bytes
                    calldataload(0)
                )
        }
        _executeUniV3IfSelector(selector);

        _executeDodoV2IfSelector(selector);

        // we do not allow a fallthrough
        assembly {
            revert(0, 0)
        }
    }
}
