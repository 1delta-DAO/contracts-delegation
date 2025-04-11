// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {MorphoFlashLoanCallback} from "./MorphoCallback.sol";
import {AaveV2FlashLoanCallback} from "./AaveV2Callback.sol";
import {BalancerV2FlashLoanCallback} from "./BalancerV2Callback.sol";
import {AaveV3FlashLoanCallback} from "./AaveV3Callback.sol";

/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks is
    MorphoFlashLoanCallback,
    AaveV2FlashLoanCallback,
    AaveV3FlashLoanCallback,
    BalancerV2FlashLoanCallback //
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
            MorphoFlashLoanCallback,
            AaveV2FlashLoanCallback,
            AaveV3FlashLoanCallback,
            BalancerV2FlashLoanCallback //
        )
    {}
}
