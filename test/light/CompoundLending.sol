// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {COMPOUND_V3_DATA_8453} from "./data/COMPOUND_V3_DATA_8453.sol";
import "./utils/CalldataLib.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract CompoundComposerLightTest is Test, ComposerUtils, COMPOUND_V3_DATA_8453 {
    uint16 internal constant COMPOUND_V3_ID = 2000;

    OneDeltaComposerLight oneDV2;

    address internal constant user = address(984327);

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_compoundV3_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comet = COMPOUND_V3_USDC_COMET;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

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
        bytes memory d = CalldataLib.encodeCompoundV3Withdraw(token, false, amountToBorrow, user, comet, token == cometToBase[comet]);

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
        IERC20All(token).approve(address(oneDV2), type(uint).max);

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

    function depositToCompoundV3(address token, address userAddress, uint amount, address comet) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV3Deposit(token, false, amount, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV3(address token, address userAddress, uint amountToBorrow, address comet) internal {
        vm.prank(userAddress);
        IERC20All(comet).allow(address(oneDV2), true);

        bytes memory d = CalldataLib.encodeCompoundV3Borrow(token, false, amountToBorrow, userAddress, comet);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }
}
