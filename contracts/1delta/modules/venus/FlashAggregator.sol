// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {LendingOps, IERC20} from "./VenusOps.sol";
import {TokenTransfer} from "../../libraries/TokenTransfer.sol";

// solhint-disable max-line-length

/**
 * @title FlashAggregator for Venus
 * @notice Adds money market and default transfer functions to margin trading
 */
contract VenusFlashAggregator is LendingOps, TokenTransfer {
    constructor(address _cNative, address _wNative) LendingOps(_cNative, _wNative) {}

    function deposit(address underlying, uint256 amount) external {
        _transferERC20TokensFrom(underlying, msg.sender, address(this), amount);
        _deposit(underlying, amount, msg.sender);
    }

    function withdraw(address underlying, uint256 amount) external {
        _withdraw(underlying, amount, msg.sender);
        _transferERC20Tokens(underlying, msg.sender, amount);
    }

    function borrow(address underlying, uint256 amount) external {
        _borrow(underlying, amount, msg.sender);
        _transferERC20Tokens(underlying, msg.sender, amount);
    }

    function repay(address underlying, uint256 amount) external {
        _transferERC20TokensFrom(underlying, msg.sender, address(this), amount);
        _repay(underlying, amount, msg.sender);
    }
}
