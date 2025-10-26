// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {AaveV2FlashLoanCallback} from "./callbacks/AaveV2Callback.sol";
import {AaveV3FlashLoanCallback} from "./callbacks/AaveV3Callback.sol";
import {MorphoFlashLoanCallback} from "./callbacks/MorphoCallback.sol";

/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks is
    AaveV2FlashLoanCallback,
    AaveV3FlashLoanCallback,
    MorphoFlashLoanCallback //
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
            AaveV2FlashLoanCallback,
            AaveV3FlashLoanCallback,
            MorphoFlashLoanCallback //
        )
    {}
}
