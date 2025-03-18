// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "./utils/CalldataLib.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract CompoundComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V3_ID = 2000;

    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal COMPOUND_V3_USDC_COMET;
    address internal WETH;
    string internal lender;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE);
        lender = Lenders.COMPOUND_V3_USDC;
        USDC = chain.getTokenAddress(Tokens.USDC);
        COMPOUND_V3_USDC_COMET =  chain.getLendingController(lender);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_compoundV3_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Deposit(token, false, amount, user, comet);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_compoundV3_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV3(depositToken, user, amount, comet);

        vm.prank(user);
        IERC20All(comet).allow(address(oneDV2), true);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV3Borrow(token, false, amountToBorrow, user, comet);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV3_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        depositToCompoundV3(token, user, amount, comet);

        vm.prank(user);
        IERC20All(comet).allow(address(oneDV2), true);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV3Withdraw(
            token, false, amountToBorrow, user, comet, token == chain.getCometToBase(lender)
        );

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV3_repay() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV3(depositToken, user, amount, comet);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV3(token, user, amountToBorrow, comet);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Repay(token, false, amountToRepay, user, comet);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToCompoundV3(address token, address userAddress, uint256 amount, address comet) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Deposit(token, false, amount, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV3(address token, address userAddress, uint256 amountToBorrow, address comet) internal {
        vm.prank(userAddress);
        IERC20All(comet).allow(address(oneDV2), true);

        bytes memory d = CalldataLib.encodeCompoundV3Borrow(token, false, amountToBorrow, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }
}
