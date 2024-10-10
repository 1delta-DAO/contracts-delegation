// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.27;

/**
 * @title IFlashLoanReceiver interface
 * @notice Interface for the Aave fee IFlashLoanReceiver.
 * @author Aave
 * @dev implement this interface to develop a flashloan-compatible flashLoanReceiver contract
 **/
interface IFlashLoanReceiver {
    /**
     * @dev When `flashLoanSimple` is called on the the Aave pool, it invokes the `executeOperation` hook on the recipient.
     *  We assume that the flash loan fee and params have been pre-computed
     *  We never expect more than one token to be flashed
     *  We assume that the asset loaned is already infinite-approved (this->flashPool)
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    ) external returns (bool);

    /**
     * @dev Balancer flash loan call
     * Gated via flash loan gateway flag to prevent calls from sources other than this contract
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external;
}
