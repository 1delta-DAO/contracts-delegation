// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {IVToken, IERC20Minimal} from "./interfaces.sol";

import {OneDeltaBNBFixture} from "./OneDeltaBNBFixture.f.sol";

contract OneDeltaVenuseMoneyMarketTest is OneDeltaBNBFixture, Test {
    function setUp() public {
        // select bnb chain to fork
        vm.createSelectFork({blockNumber: 34_958_582, urlOrAlias: "https://rpc.ankr.com/bsc"});
        // set up 1delta
        deployAndInit1delta();

        // fund 10 first assets
        for (uint i; i < 10; i++) {
            address asset = assets[i];
            vm.startPrank(asset);
            uint balance = IERC20Minimal(asset).balanceOf(asset);
            if (balance > 0) IERC20Minimal(asset).transfer(address(this), balance);
            vm.stopPrank();
        }
    }

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
}
