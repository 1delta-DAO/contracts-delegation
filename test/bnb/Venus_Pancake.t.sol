// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.25;

import "forge-std/console.sol";

import {IVToken, IERC20Minimal} from "./interfaces.sol";

import {OneDeltaBNBFixture} from "./OneDeltaBNBFixture.f.sol";

contract OneDeltaVenuseMoneyMarketTest is OneDeltaBNBFixture {
    function test_margin_open_exact_in() public {
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

    function test_margin_close_exact_in() public {
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

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint balDelta = borrowBalBefore - balRec;
        assertApproxEqAbs(balDelta, received, 1e10);

        // check collateral
        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        balDelta = collatBalBefore - balRec;
        assertApproxEqAbs(balDelta, withdrawAmount, 1e10);
    }

    function test_margin_open_exact_in_V2() public {
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
        bytes memory path = getOpenSingleV2(USDC, wNative);

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

    function test_margin_close_exact_in_V2() public {
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
        bytes memory path = getCloseSingleV2(wNative, USDC);
        uint withdrawAmount = amount / 4; // 25%
        uint received;
        {
            uint gas = gasleft();
            console.log("close");
            received = aggregator.flashSwapExactIn(withdrawAmount, 0, path);
            uint gasConsumed = gas - gasleft();
            console.log("gasConsumed", gasConsumed);
        }

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint balDelta = borrowBalBefore - balRec;
        assertApproxEqAbs(balDelta, received, 1e10);

        // check collateral
        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        balDelta = collatBalBefore - balRec;
        assertApproxEqAbs(balDelta, withdrawAmount, 1e10);
    }

    function test_margin_open_exact_out() public {
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

        // borrow amount is 2x depo assuming price of 300
        uint depoAmount = 2 * amount;
        // create calldata
        bytes memory path = getOpenSingleExactOut(USDC, wNative);

        uint gas = gasleft();
        uint received = aggregator.flashSwapExactOut(depoAmount, type(uint).max, path);
        uint gasConsumed = gas - gasleft();
        console.log("gasConsumed", gasConsumed);

        uint balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        assertApproxEqAbs(balRec, depoAmount + amount, 1e10);

        balRec = IVToken(vTokenBorrow).borrowBalanceCurrent(address(this));
        assertApproxEqAbs(balRec, received, 1e10);
        console.log("collateral", balRec);
    }

    function test_margin_close_exact_out() public {
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
        bytes memory path = getCloseSingleExactOut(wNative, USDC);
        uint repayAmount = borrowAmount / 4; // 25%
        uint received;
        {
            uint gas = gasleft();
            console.log("close");
            received = aggregator.flashSwapExactOut(repayAmount, type(uint).max, path);
            uint gasConsumed = gas - gasleft();
            console.log("gasConsumed", gasConsumed);
        }

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint balDelta = borrowBalBefore - balRec;
        assertApproxEqAbs(balDelta, repayAmount, 1e10);

        // check collateral
        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        balDelta = collatBalBefore - balRec;
        assertApproxEqAbs(balDelta, received, 1e10);
    }

    function test_margin_open_exact_out_V2() public {
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

        // borrow amount is 2x depo assuming price of 300
        uint depoAmount = 2 * amount;
        // create calldata
        bytes memory path = getOpenSingleV2ExactOut(USDC, wNative);

        uint gas = gasleft();
        uint received = aggregator.flashSwapExactOut(depoAmount, type(uint).max, path);
        uint gasConsumed = gas - gasleft();
        console.log("gasConsumed", gasConsumed);

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        assertApproxEqAbs(balRec, received, 1e10);

        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        assertApproxEqAbs(balRec, amount + depoAmount, 1e10);
        console.log("collateral", balRec);
    }

    function test_margin_close_exact_out_V2() public {
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
        bytes memory path = getCloseSingleV2ExactOut(wNative, USDC);
        uint repayAmount = amount / 4; // 25%
        uint received;
        {
            uint gas = gasleft();
            console.log("close");
            received = aggregator.flashSwapExactOut(repayAmount, type(uint).max, path);
            uint gasConsumed = gas - gasleft();
            console.log("gasConsumed", gasConsumed);
        }

        uint balRec = IVToken(vTokenBorrow).borrowBalanceStored(address(this));
        uint balDelta = borrowBalBefore - balRec;
        assertApproxEqAbs(balDelta, repayAmount, 1e10);

        // check collateral
        balRec = IVToken(vToken).balanceOfUnderlying(address(this));
        balDelta = collatBalBefore - balRec;
        assertApproxEqAbs(balDelta, received, 1e10);
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

    function getOpenSingleV2(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 0;
        uint8 poolId = 50;
        uint8 actionId = 6;
        uint8 endId = 2;
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseSingleV2(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 0;
        uint8 poolId = 50;
        uint8 actionId = 7;
        uint8 endId = 3;
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    // eo
    function getOpenSingleExactOut(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 500;
        uint8 poolId = 0;
        uint8 actionId = 3;
        uint8 endId = 2;
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCloseSingleExactOut(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 500;
        uint8 poolId = 0;
        uint8 actionId = 4;
        uint8 endId = 3;
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getOpenSingleV2ExactOut(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 0;
        uint8 poolId = 50;
        uint8 actionId = 3;
        uint8 endId = 2;
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCloseSingleV2ExactOut(address tokenIn, address tokenOut) private pure returns (bytes memory data) {
        uint24 fee = 0;
        uint8 poolId = 50;
        uint8 actionId = 4;
        uint8 endId = 3;
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }
}
