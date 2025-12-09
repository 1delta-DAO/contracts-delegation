// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {AaveV2FlashLoanCallback} from "./callbacks/AaveV2Callback.sol";
import {AaveV3FlashLoanCallback} from "./callbacks/AaveV3Callback.sol";
import {MorphoFlashLoanCallback} from "./callbacks/MorphoCallback.sol";
import {BalancerV2FlashLoanCallback} from "./callbacks/BalancerV2Callback.sol";

/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks is
    AaveV2FlashLoanCallback,
    AaveV3FlashLoanCallback,
    MorphoFlashLoanCallback,
    BalancerV2FlashLoanCallback //
{
    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
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
            AaveV2FlashLoanCallback,
            AaveV3FlashLoanCallback,
            MorphoFlashLoanCallback,
            BalancerV2FlashLoanCallback //
        )
    {}
}

