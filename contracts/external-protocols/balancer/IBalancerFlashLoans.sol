// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./IFlashLoanRecipient.sol";
import "./Fees.sol";

/**
 * @dev Handles Flash Loans through the Vault. Calls the `receiveFlashLoan` hook on the flash loan recipient
 * contract, which implements the `IFlashLoanRecipient` interface.
 */
interface IBalancerFlashLoans {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}
