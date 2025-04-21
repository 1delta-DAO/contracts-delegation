// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;

interface IVToken {
    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOfUnderlying(address owner) external returns (uint256);

    function totalBorrowsCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function seize(address liquidator, address borrower, uint256 seizeTokens) external returns (uint256);

    /**
     * Admin Function **
     */
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint256);

    /**
     * Admin Function **
     */
    function _acceptAdmin() external returns (uint256);

    /**
     * Admin Function **
     */
    function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

    /**
     * Admin Function **
     */
    function _reduceReserves(uint256 reduceAmount) external returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function supplyRatePerBlock() external view returns (uint256);

    function getCash() external view returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function accrueInterest() external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function mint() external payable; // vBNB does not return a value

    function mintBehalf(address receiver, uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    /**
     * Admin Functions **
     */
    function _addReserves(uint256 addAmount) external returns (uint256);
}

interface IERC20Minimal {
    function mint(uint256 value) external returns (bool);

    function decimals() external returns (uint8);

    function balanceOf(address u) external returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function withdraw(uint256 am) external;
}
