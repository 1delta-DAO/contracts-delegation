// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

interface IVToken {
    function transfer(address dst, uint amount) external returns (bool);

    function transferFrom(address src, address dst, uint amount) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function balanceOfUnderlying(address owner) external returns (uint);

    function totalBorrowsCurrent() external returns (uint);

    function borrowBalanceCurrent(address account) external returns (uint);

    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);

    /*** Admin Function ***/
    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint);

    /*** Admin Function ***/
    function _acceptAdmin() external returns (uint);

    /*** Admin Function ***/
    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);

    /*** Admin Function ***/
    function _reduceReserves(uint reduceAmount) external returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);

    function borrowRatePerBlock() external view returns (uint);

    function supplyRatePerBlock() external view returns (uint);

    function getCash() external view returns (uint);

    function exchangeRateCurrent() external returns (uint);

    function accrueInterest() external returns (uint);

    function borrowBalanceStored(address account) external view returns (uint);

    function exchangeRateStored() external view returns (uint);

    function mint(uint mintAmount) external returns (uint);

    function mint() external payable; // vBNB does not return a value

    function mintBehalf(address receiver, uint mintAmount) external returns (uint);

    function redeem(uint redeemTokens) external returns (uint);

    function redeemUnderlying(uint redeemAmount) external returns (uint);

    function borrow(uint borrowAmount) external returns (uint);

    function repayBorrow(uint repayAmount) external returns (uint);

    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);

    /*** Admin Functions ***/

    function _addReserves(uint addAmount) external returns (uint);
}

interface IERC20Minimal {
    function mint(uint256 value) external returns (bool);

    function decimals() external returns (uint8);

    function balanceOf(address u) external returns (uint);

    function transfer(address to, uint amount) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function withdraw(uint am) external;
}
