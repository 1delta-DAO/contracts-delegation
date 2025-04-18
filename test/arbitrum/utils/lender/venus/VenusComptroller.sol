// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

enum Action {
    MINT,
    REDEEM,
    BORROW,
    REPAY,
    SEIZE,
    LIQUIDATE,
    TRANSFER,
    ENTER_MARKET,
    EXIT_MARKET
}

/**
 * @title ComptrollerInterface
 * @author Venus
 * @notice Interface implemented by the `Comptroller` contract.
 */
interface ComptrollerInterface {
    /**
     * Assets You Are In **
     */
    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function exitMarket(address vToken) external returns (uint256);

    /**
     * Policy Hooks **
     */
    function preMintHook(address vToken, address minter, uint256 mintAmount) external;

    function preRedeemHook(address vToken, address redeemer, uint256 redeemTokens) external;

    function preBorrowHook(address vToken, address borrower, uint256 borrowAmount) external;

    function preRepayHook(address vToken, address borrower) external;

    function preLiquidateHook(
        address vTokenBorrowed,
        address vTokenCollateral,
        address borrower,
        uint256 repayAmount,
        bool skipLiquidityCheck
    )
        external;

    function updateDelegate(address delegate, bool allowBorrows) external;

    function preSeizeHook(address vTokenCollateral, address vTokenBorrowed, address liquidator, address borrower) external;

    function borrowVerify(address vToken, address borrower, uint256 borrowAmount) external;

    function mintVerify(address vToken, address minter, uint256 mintAmount, uint256 mintTokens) external;

    function redeemVerify(address vToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) external;

    function repayBorrowVerify(address vToken, address payer, address borrower, uint256 repayAmount, uint256 borrowerIndex) external;

    function liquidateBorrowVerify(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    )
        external;

    function seizeVerify(address vTokenCollateral, address vTokenBorrowed, address liquidator, address borrower, uint256 seizeTokens) external;

    function transferVerify(address vToken, address src, address dst, uint256 transferTokens) external;

    function preTransferHook(address vToken, address src, address dst, uint256 transferTokens) external;

    function isComptroller() external view returns (bool);

    /**
     * Liquidity/Liquidation Calculations **
     */
    function liquidateCalculateSeizeTokens(
        address vTokenBorrowed,
        address vTokenCollateral,
        uint256 repayAmount
    )
        external
        view
        returns (uint256, uint256);

    function getAllMarkets() external view returns (address[] memory);

    function actionPaused(address market, Action action) external view returns (bool);
}

/**
 * @title ComptrollerViewInterface
 * @author Venus
 * @notice Interface implemented by the `Comptroller` contract, including only some util view functions.
 */
interface ComptrollerViewInterface {
    function markets(address) external view returns (bool, uint256);

    function oracle() external view returns (address);

    function getAssetsIn(address) external view returns (address[] memory);

    function closeFactorMantissa() external view returns (uint256);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function minLiquidatableCollateral() external view returns (uint256);

    function getRewardDistributors() external view returns (address[] memory);

    function getAllMarkets() external view returns (address[] memory);

    function borrowCaps(address) external view returns (uint256);

    function supplyCaps(address) external view returns (uint256);

    function approvedDelegates(address user, address delegate) external view returns (bool);
}
