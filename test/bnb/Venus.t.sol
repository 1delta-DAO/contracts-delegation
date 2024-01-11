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
        address asset;
        // fund 10 first assets
        for (uint i; i < 10; i++) {
            asset = assets[i];
            vm.startPrank(asset);
            uint balance = IERC20Minimal(asset).balanceOf(asset);
            if (balance > 0) IERC20Minimal(asset).transfer(address(this), balance);
            vm.stopPrank();
        }
        asset = wNative;
        vm.startPrank(asset);
        IERC20Minimal(asset).transfer(address(this), 1e20);
        vm.stopPrank();
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

    function test_margin_open() public {
        // deposit 10 BNB, borrow 6,000 BUSC, depo approx. 20

        // asset config
        address vToken = vNative;
        address underlying = wNative;

        address vTokenBorrow = vUSDC;
        address underlyingBorrow = USDC;
        uint baseAmount = 10;

        // 10 units to deposit
        uint amount = baseAmount * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(vToken, amount);
        // call mint
        IVToken(vToken).mint{value: amount}();
        address[] memory enter = new address[](1);
        enter[0] = vToken;
        comptroller.enterMarkets(enter);
        // approve vToken
        comptroller.updateDelegate(oneDelta, true);

        uint approxPrice = 300; // BNB is about 300 USDC
        // borrow amount is 2x depo assuming price of 300
        uint borrowAmount = 2 * approxPrice * baseAmount * 10 ** IERC20Minimal(underlyingBorrow).decimals();
        // create calldata
        bytes memory path = getOpenSingle(USDC, wNative);

        uint gas = gasleft();
        uint received = aggregator.flashSwapExactIn(borrowAmount, 0, path);
        uint gasConsumed = gas - gasleft();
        console.log("gasConsumed", gasConsumed);

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        assertApproxEqAbs(balRec, borrowAmount, 1e10);

        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        assertApproxEqAbs(balRec, amount + received, 1e10);
        console.log("collateral", balRec);
    }

    function test_margin_close() public {
        // deposit 10 BNB, borrow 6,000 BUSC, depo approx. 20

        // asset config
        address vToken = vNative;
        address underlying = wNative;

        address vTokenBorrow = vUSDC;
        address underlyingBorrow = USDC;
        uint baseAmount = 10;

        // 10 units to deposit
        uint amount = baseAmount * 10 ** IERC20Minimal(underlying).decimals();
        // approve delta
        IERC20Minimal(underlying).approve(vToken, amount);
        // call mint
        IVToken(vToken).mint{value: amount}();
        address[] memory enter = new address[](1);
        enter[0] = vToken;
        comptroller.enterMarkets(enter);
        // approve vToken
        // comptroller.updateDelegate(oneDelta, true);

        uint approxPrice = 300; // BNB is about 300 USDC
        // borrow amount is 2x depo assuming price of 300
        uint borrowAmount = (approxPrice * baseAmount * 10 ** IERC20Minimal(underlyingBorrow).decimals()) / 3; // 30%

        IVToken(vTokenBorrow).borrow(borrowAmount);
        // approve withdrawal
        IVToken(vToken).approve(address(aggregator), type(uint).max);
        uint borrowBalBefore = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint collatBalBefore = IVToken(vToken).balanceOfUnderlying(address(this));

        // create calldata
        bytes memory path = getCloseSingle(wNative, USDC);
        uint withdrawAmount = amount / 4; // 25%
        uint received;
        {
            uint gas = gasleft();
            console.log("close");
            received = aggregator.flashSwapExactIn(withdrawAmount, 0, path);
            uint gasConsumed = gas - gasleft();
            console.log("gasConsumed", gasConsumed);
        }
        console.log("received", received);

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint balDelta = borrowBalBefore - balRec;
        assertApproxEqAbs(balDelta, received, 1e10);

        // check collateral
        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        balDelta = collatBalBefore - balRec;
        assertApproxEqAbs(balDelta, withdrawAmount, 1e10);
    }

    function getOpenSingle(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 500;
        uint8 poolId = 0;
        uint8 actionId = 6;
        uint8 endId = 2;
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseSingle(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 500;
        uint8 poolId = 0;
        uint8 actionId = 7;
        uint8 endId = 3;
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }
}
