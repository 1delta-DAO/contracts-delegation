// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.26;

/**
 * @title IFlashLoanReceiver interface
 * @notice Interface for the Aave fee IFlashLoanReceiver.
 * @author Aave
 * @dev implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 **/
interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool);

    struct DeltaParams {
        address baseAsset; // the asset paired with the flash loan
        address target; // the swap target
        uint8 marginTradeType; // trade type determining the lending actions
        // 0 = Margin open
        // 1 = margin close
        // 2 = collateral / open
        // 3 = debt / close
        uint8 interestRateModeIn; // aave interest mode
        uint8 interestRateModeOut; // aave interest mode
        bool withdrawMax; // a flag that indicates that the entire balance is withdrawn
    }

    function executeOnLendle(
        address asset,
        uint256 amount,
        DeltaParams calldata deltaParams, // params are kept separate
        bytes calldata swapCalldata
    ) external payable;
}
