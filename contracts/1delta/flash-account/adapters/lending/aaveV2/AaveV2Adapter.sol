// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FlashAccountAdapterBase} from "@flash-account/adapters/FlashAccountAdapterBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";
import "@flash-account/common/FlashAccountError.sol";

/**
 * @title AaveV2Adapter
 * @notice This contract allows users to supply and repay assets on Aave V2.
 * @dev Inherits from FlashAccountAdapterBase to manage flash account operations.
 */
contract AaveV2Adapter is FlashAccountAdapterBase {
    uint16 private constant REFERRAL_CODE = 0;
    uint256 private constant VARIABLE_RATE_MODE = 2;
    uint256 private constant STABLE_RATE_MODE = 1;

    // Aave V2 LendingPool address
    address public immutable lendingPool;

    /**
     * @notice Constructor for the AaveV2Adapter contract.
     * @param weth_ The address of the WETH token.
     * @param lendingPool_ The address of the Aave V2 LendingPool.
     */
    constructor(address weth_, address lendingPool_) FlashAccountAdapterBase(weth_) {
        if (lendingPool_ == address(0)) revert ZeroAddress();
        lendingPool = lendingPool_;
    }

    /**
     * @notice Supply ERC20 assets to Aave V2
     * @param asset The underlying token address (e.g., USDC)
     * @param onbehalfOf The address that will receive the aTokens
     * @return success 0 if successful
     */
    function supply(address asset, address onbehalfOf) external returns (uint256 success) {
        if (onbehalfOf == address(0)) revert ZeroAddress();

        uint256 availableBalance = _getBalance(asset, address(this));
        if (availableBalance == 0) revert ZeroAmount();

        // Check if token is approved
        if (!isApprovedAddress[asset][lendingPool]) {
            SafeERC20.safeIncreaseAllowance(IERC20(asset), lendingPool, type(uint256).max);
            isApprovedAddress[asset][lendingPool] = true;
        }

        // deposit
        ILendingPool(lendingPool).deposit(asset, availableBalance, onbehalfOf, REFERRAL_CODE);

        return 0;
    }

    /**
     * @notice Supply native tokens (ETH) to Aave V2
     * @param onbehalfOf The address that will receive the aTokens
     * @return success 0 if successful
     */
    function supplyValue(address onbehalfOf) external payable returns (uint256 success) {
        if (msg.value == 0) revert ZeroAmount();
        if (onbehalfOf == address(0)) revert ZeroAddress();

        // Wrap native ETH to WETH
        _wrap(msg.value);

        // Check if WETH is approved
        if (!isApprovedAddress[WETH][lendingPool]) {
            SafeERC20.safeIncreaseAllowance(IERC20(WETH), lendingPool, type(uint256).max);
            isApprovedAddress[WETH][lendingPool] = true;
        }

        // Execute the deposit
        ILendingPool(lendingPool).deposit(WETH, msg.value, onbehalfOf, REFERRAL_CODE);

        return 0;
    }

    /**
     * @notice Repay a borrow with ERC20 tokens
     * @param asset The underlying token address (e.g., USDC)
     * @param onbehalfOf The address whose debt is being repaid
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     * @param rateMode The interest rate mode (1 for stable, 2 for variable)
     * @return repaidAmount Amount repaid
     */
    function repay(address asset, address onbehalfOf, uint256 amount, uint256 rateMode) external returns (uint256 repaidAmount) {
        if (onbehalfOf == address(0)) revert ZeroAddress();
        if (onbehalfOf == address(this)) revert CantRepaySelf();

        uint256 availableBalance = _getBalance(asset, address(this));
        if (availableBalance == 0) revert ZeroAmount();

        // Check if token is approved
        if (!isApprovedAddress[asset][lendingPool]) {
            SafeERC20.safeIncreaseAllowance(IERC20(asset), lendingPool, type(uint256).max);
            isApprovedAddress[asset][lendingPool] = true;
        }

        // Determine repay amount
        uint256 repayAmount = amount;
        if (amount == type(uint256).max || amount > availableBalance) {
            repayAmount = availableBalance;
        }

        // Execute the repay
        repaidAmount = ILendingPool(lendingPool).repay(asset, repayAmount, rateMode, onbehalfOf);

        // Refund any excess
        uint256 excess = _getBalance(asset, address(this));
        if (excess > 0) {
            _transferERC20(asset, onbehalfOf, excess);
        }

        return repaidAmount;
    }

    /**
     * @notice Repay a borrow with native tokens (ETH)
     * @param onbehalfOf The address whose debt is being repaid
     * @param amount The amount to repay (use type(uint256).max for full repayment)
     * @param rateMode The interest rate mode (1 for stable, 2 for variable)
     * @return repaidAmount Amount repaid
     */
    function repayValue(address onbehalfOf, uint256 amount, uint256 rateMode) external payable returns (uint256 repaidAmount) {
        if (msg.value == 0) revert ZeroAmount();
        if (onbehalfOf == address(0)) revert ZeroAddress();
        if (onbehalfOf == address(this)) revert CantRepaySelf();

        // Wrap native ETH to WETH
        _wrap(msg.value);

        // Check if WETH is approved
        if (!isApprovedAddress[WETH][lendingPool]) {
            SafeERC20.safeIncreaseAllowance(IERC20(WETH), lendingPool, type(uint256).max);
            isApprovedAddress[WETH][lendingPool] = true;
        }

        // Determine repay amount
        uint256 repayAmount = amount;
        if (amount == type(uint256).max || amount > msg.value) {
            repayAmount = msg.value;
        }

        // Execute the repay
        repaidAmount = ILendingPool(lendingPool).repay(WETH, repayAmount, rateMode, onbehalfOf);

        // Refund any excess WETH by unwrapping and sending native
        uint256 excessWETH = _getBalance(WETH, address(this));
        if (excessWETH > 0) {
            _unwrap(excessWETH);
            _transferNative(onbehalfOf, address(this).balance);
        }

        return repaidAmount;
    }
}
