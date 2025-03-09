// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";
import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {GRANARY_DATA_8453} from "./data/GRANARY_DATA_8453.sol";
import "./utils/CalldataLib.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract AaveV2LightTest is Test, GRANARY_DATA_8453 {
    uint16 internal constant GRANARY = 1000;
    OneDeltaComposerBase oneD;
    OneDeltaComposerLight oneDV2;

    address internal constant user = address(984327);

    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerBase();
        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_granary_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = GRANARY_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveV2Deposit(token, false, amount, user, pool);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_granary_borrow() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = GRANARY_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);
        address dToken = lendingTokens[token].vToken;
        vm.prank(user);
        IERC20All(dToken).approveDelegation(address(oneDV2), type(uint).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveV2Borrow(token, false, amountToBorrow, user, 2, pool);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_granary_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = GRANARY_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        address aToken = lendingTokens[token].aToken;
        vm.prank(user);
        IERC20All(aToken).approve(address(oneDV2), type(uint).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeAaveV2Withdraw(token, false, amountToBorrow, user, aToken, pool);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_granary_repay() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = GRANARY_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        depositToAave(token, user, amount, pool);

        uint256 amountToBorrow = 10.0e6;
        borrowFromAave(token, user, amountToBorrow, pool);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        bytes memory d = CalldataLib.encodeAaveV2Repay(token, false, amountToRepay, user, 2, lendingTokens[token].vToken, pool);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToAave(address token, address userAddress, uint amount, address pool) internal {
        deal(token, userAddress, 1000.0e6);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveV2Deposit(token, false, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromAave(address token, address userAddress, uint amountToBorrow, address pool) internal {
        vm.prank(userAddress);
        IERC20All(lendingTokens[token].vToken).approveDelegation(address(oneDV2), type(uint).max);

        bytes memory d = CalldataLib.encodeAaveV2Borrow(token, false, amountToBorrow, userAddress, 2, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }

    // 0x238d6579
    // 0000000000000000000000004200000000000000000000000000000000000006
    // 0000000000000000000000004200000000000000000000000000000000000007
    // 0000000000000000000000004200000000000000000000000000000000000008
    // 0000000000000000000000004200000000000000000000000000000000000009
    // 0000000000000000000000000000000000000000000000000bef55718ad60000
    // 0000000000000000000000000000000000000000000000000000000000084cea
    // 000000000000000000000000937ce2d6c488b361825d2db5e8a70e26d48afed5
    // 0000000000000000000000000000000000000000000000000000000000000100
    // 0000000000000000000000000000000000000000000000000000000000000038
    // 220000000000000000000000000000000000000000937ce2d6c488b361825d2d
    // b5e8a70e26d48afed5020000000000000000000000084cea0000000000000000
}
