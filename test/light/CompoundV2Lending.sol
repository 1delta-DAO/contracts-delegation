// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";
import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {ComposerLightBaseTest} from "./ComposerLightBaseTest.sol";
import {ChainIds, TokenNames} from "./chain/Lib.sol";
import "./utils/CalldataLib.sol";

contract CompoundComposerLightTest is ComposerLightBaseTest {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal VENUS_COMPTROLLER;

    function setUp() public virtual {
        // initialize the chain
        _init(ChainIds.ARBITRUM);
        USDC = chain.getTokenAddress(TokenNames.USDC);
        WETH = chain.getTokenAddress(TokenNames.WETH);
        VENUS_COMPTROLLER = chain.getTokenAddress(TokenNames.VENUS_COMPTROLLER);

        oneDV2 = new OneDeltaComposerLight();
    }

    function test_light_compoundV2_deposit() external {
        vm.assume(user != address(0));

        address token = USDC;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        address cToken = chain.getVenusLendingTokens(token);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, false, amount, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function test_light_compoundV2_borrow() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        address cToken = chain.getVenusLendingTokens(token);
        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller);

        vm.prank(user);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV2Borrow(token, false, amountToBorrow, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV2_withdraw() external {
        vm.assume(user != address(0));

        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;
        uint256 amount = 100.0e6;
        deal(token, user, amount);

        depositToCompoundV2(token, user, amount, comptroller);

        address cToken = chain.getVenusLendingTokens(token);

        vm.prank(user);
        IERC20All(cToken).approve(address(oneDV2), type(uint256).max);

        uint256 amountToBorrow = 10.0e6;
        bytes memory d = CalldataLib.encodeCompoundV2Withdraw(token, false, amountToBorrow, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(d);
    }

    function test_light_compoundV2_repay() external {
        vm.assume(user != address(0));

        address depositToken = WETH;
        address token = USDC;
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1.0e18;
        deal(token, user, amount);

        depositToCompoundV2(depositToken, user, amount, comptroller);

        uint256 amountToBorrow = 10.0e6;
        borrowFromCompoundV2(token, user, amountToBorrow, comptroller);

        vm.prank(user);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        uint256 amountToRepay = 7.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amountToRepay //
        );

        address cToken = chain.getVenusLendingTokens(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, false, amountToRepay, user, cToken);

        vm.prank(user);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function depositToCompoundV2(address token, address userAddress, uint256 amount, address comptroller) internal {
        deal(token, userAddress, amount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = chain.getVenusLendingTokens(token);

        vm.prank(userAddress);
        IERC20All(comptroller).enterMarkets(cTokens);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        address cToken = chain.getVenusLendingTokens(token);
        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, false, amount, userAddress, cToken);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function borrowFromCompoundV2(address token, address userAddress, uint256 amountToBorrow, address comptroller)
        internal
    {
        vm.prank(userAddress);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        address cToken = chain.getVenusLendingTokens(token);
        bytes memory d = CalldataLib.encodeCompoundV2Borrow(token, false, amountToBorrow, userAddress, cToken);

        vm.prank(userAddress);
        oneDV2.deltaCompose(d);
    }
}
