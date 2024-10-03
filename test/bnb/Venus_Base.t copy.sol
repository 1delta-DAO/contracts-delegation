// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.27;

import "forge-std/console.sol";

import {IVToken, IERC20Minimal} from "./interfaces.sol";

import {OneDeltaBNBFixture} from "./OneDeltaBNBFixture.f.sol";

contract OneDeltaVenuseMoneyMarketTest is OneDeltaBNBFixture {
    function test_depo_base() public {
        // asset config
        uint i = 1;
        address vToken = vTokens[i];
        address underlying = assets[i];

        // 10 units to deposit
        uint amount = 10 * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(oneDelta, amount);
        // call deposit
        aggregator.deposit(underlying, amount);

        // validate balance
        uint balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        console.log(balRec, amount);
        assertApproxEqAbs(balRec, amount, 1e10);
    }

    function test_withdraw_base() public {
        // asset config
        uint i = 0;
        address vToken = vTokens[i];
        address underlying = assets[i];

        // 10 units to deposit
        uint amount = 10 * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(vToken, amount);
        // call mint
        IVToken(vToken).mint(amount);

        // approve vToken
        IVToken(vToken).approve(oneDelta, type(uint).max);

        uint withdrawAmount = (amount * 30) / 100;

        // withdraw
        aggregator.withdraw(underlying, withdrawAmount);

        // validate balance
        uint balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        console.log(balRec, amount - withdrawAmount);
        assertApproxEqAbs(balRec, amount - withdrawAmount, 1e10);
    }

    function test_borrow_base() public {
        // asset config
        uint deposit_i = 0;
        address vToken = vTokens[deposit_i];
        address underlying = assets[deposit_i];

        uint borrow_i = 6;
        address vTokenBorrow = vTokens[borrow_i];
        address underlyingBorrow = assets[borrow_i];
        uint baseAmount = 10;

        // 10 units to deposit
        uint amount = baseAmount * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(vToken, amount);
        // call mint
        IVToken(vToken).mint(amount);
        address[] memory enter = new address[](1);
        enter[0] = vToken;
        comptroller.enterMarkets(enter);
        // approve vToken
        comptroller.updateDelegate(oneDelta, true);

        uint borrowAmount = (baseAmount / 2) * 10 ** IERC20Minimal(underlyingBorrow).decimals();
        // borrow
        aggregator.borrow(underlyingBorrow, borrowAmount);

        // validate balance
        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        console.log(balRec, borrowAmount);
        assertApproxEqAbs(balRec, borrowAmount, 1e10);
    }

    function test_repay_base() public {
        // asset config
        uint deposit_i = 0;
        address vToken = vTokens[deposit_i];
        address underlying = assets[deposit_i];

        uint borrow_i = 6;
        address vTokenBorrow = vTokens[borrow_i];
        address underlyingBorrow = assets[borrow_i];
        uint baseAmount = 10;

        // 10 units to deposit
        uint amount = baseAmount * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(vToken, amount);
        // call mint
        IVToken(vToken).mint(amount);
        address[] memory enter = new address[](1);
        enter[0] = vToken;
        comptroller.enterMarkets(enter);
        // // approve vToken
        // comptroller.updateDelegate(oneDelta, true);

        uint borrowAmount = (baseAmount / 2) * 10 ** IERC20Minimal(underlyingBorrow).decimals();

        // borrow
        IVToken(vTokenBorrow).borrow(borrowAmount);

        uint repay = borrowAmount / 2;

        IERC20Minimal(underlyingBorrow).approve(oneDelta, repay);

        // repay
        aggregator.repay(underlyingBorrow, repay);

        // validate balance
        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        console.log(balRec, borrowAmount - repay);
        assertApproxEqAbs(balRec, borrowAmount - repay, 1e10);
    }
}
