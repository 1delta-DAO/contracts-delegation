// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {ComposerLightBaseTest} from "./ComposerLightBaseTest.sol";
import {ChainIds, TokenNames} from "./chain/Lib.sol";
import "./utils/CalldataLib.sol";

contract AaveV2LightTest is ComposerLightBaseTest {
    uint16 internal constant GRANARY = 1000;
    OneDeltaComposerLight oneDV2;
    address internal LBTC;
    address internal USDC;
    address internal GRANARY_POOL;

    function setUp() public virtual {
        // initialize the chain
        _init(ChainIds.BASE);
        LBTC = chain.getTokenAddress(TokenNames.LBTC);
        USDC = chain.getTokenAddress(TokenNames.USDC);
        GRANARY_POOL = chain.getTokenAddress(TokenNames.GRANERY_POOL);

        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_granary_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        address pool = GRANARY_POOL;
        deal(token, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

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
        address dToken = chain.getGranaryLendingTokens(token).vToken;
        vm.prank(user);
        IERC20All(dToken).approveDelegation(address(oneDV2), type(uint256).max);

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

        address aToken = chain.getGranaryLendingTokens(token).aToken;

        vm.prank(user);
        IERC20All(aToken).approve(address(oneDV2), type(uint256).max);

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
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        address vToken = chain.getGranaryLendingTokens(token).vToken;

        bytes memory d = CalldataLib.encodeAaveV2Repay(token, false, amountToRepay, user, 2, vToken, pool);

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

        bytes memory d = CalldataLib.encodeAaveV2Deposit(token, false, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromAave(address token, address userAddress, uint256 amountToBorrow, address pool) internal {
        address vToken = chain.getGranaryLendingTokens(token).vToken;
        vm.prank(userAddress);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        bytes memory d = CalldataLib.encodeAaveV2Borrow(token, false, amountToBorrow, userAddress, 2, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }
}
