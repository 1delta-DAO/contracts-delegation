// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILending {
    /**
     * LENDING GENERAL
     */

    // deposit ERC20 to Aave types on behalf of recipient
    function deposit(address asset, address recipient, uint8 lenderId) external payable;

    // borrow on sender's behalf
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint8 lenderId) external payable;

    // wraps the repay function
    function repay(address asset, address recipient, uint256 interestRateMode, uint8 lenderId) external payable;

    // wraps the withdraw
    function withdraw(address asset, address recipient, uint8 lenderId) external payable;

    /**
     * TRANSFER FUNCTIONS
     */

    /**
     * @notice transfer an ERC20token in
     */
    function transferERC20In(address asset, uint256 amount) external payable;

    /**
     * @notice transfer all ERC20tokens in - only required for aTokens
     */
    function transferERC20AllIn(address asset) external payable;

    /**
     * @notice transfer an a balance to the sender
     */
    function sweep(address asset) external payable;

    /**
     * @notice transfer an a balance to the recipient
     */
    function sweepTo(address asset, address recipient) external payable;

    function refundNative() external payable;

    function refundNativeTo(address payable receiver) external payable;

    /**
     * GENERIC CALL WRAPPER FOR APPROVED CALLS
     */

    // Call to an approved target (can also be the contract itself)
    // Can be for swaps or wraps
    function callTarget(address target, bytes memory data) external payable;

    /**
     * WRAPPED NATIVE HANDLER
     */

    // deposit native and wrap
    function wrap() external payable;

    function wrapTo(address recipient) external payable;

    // unwrap wrappd native and send funds to sender
    function unwrap() external payable;

    // unwrap wrappd native and send funds to a receiver
    function unwrapTo(address payable receiver) external payable;

    /**
     * PERMITS
     */
    function selfPermit(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;

    // DAI-type permit
    function selfPermitAllowed(address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external payable;

    // Aave credit delegation permit
    function selfCreditDelegate(address creditToken, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
}
