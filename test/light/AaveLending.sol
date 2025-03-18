// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";

import "./utils/CalldataLib.sol";

contract AaveLightTest is BaseTest {
    OneDeltaComposerLight oneDV2;

    address internal LBTC;
    address internal USDC;
    address internal AAVE_V3_POOL;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);

        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_aave_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, false, amount, user, pool);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_aave_borrow() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        address vToken = _getDebtToken(token);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, user, 2, pool);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_aave_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        address aToken = _getDebtToken(token);

        vm.prank(user);
        IERC20All(aToken).approve(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveWithdraw(token, false, amountToBorrow, user, aToken, pool);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_aave_repay() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = AAVE_V3_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        uint256 amountToBorrow = 10.0e6;
        borrowFromAave(token, user, amountToBorrow, pool);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        address vToken = _getDebtToken(token);

        bytes memory d = CalldataLib.encodeAaveRepay(token, false, amountToRepay, user, 2, vToken, pool);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToAave(address token, address userAddress, uint256 amount, address pool) internal {
        deal(token, userAddress, 1000.0e6);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, false, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromAave(address token, address userAddress, uint256 amountToBorrow, address pool) internal {
        address vToken = _getDebtToken(token);

        vm.prank(userAddress);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        bytes memory d = CalldataLib.encodeAaveBorrow(token, false, amountToBorrow, userAddress, 2, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    function _getDebtToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, Lenders.AAVE_V3).debt;
    }
}
