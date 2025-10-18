// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "test/composer/lending/utils/Morpho.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract CompoundV2NativeComposerLightTest is BaseTest {
    uint16 internal constant COMPOUND_V2_ID = 3000;

    IComposerLike oneDV2;

    address internal USDC;
    // address internal WETH;
    address internal WBNB;
    address internal VENUS_COMPTROLLER;
    string internal lender;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BNB_SMART_CHAIN_MAINNET;

        _init(chainName, forkBlock, true);

        lender = Lenders.VENUS;
        USDC = chain.getTokenAddress(Tokens.USDC);
        // WETH = chain.getTokenAddress(Tokens.WETH);
        WBNB = chain.getTokenAddress(Tokens.WBNB);
        VENUS_COMPTROLLER = chain.getLendingController(lender);

        // use base for the non chain-specific integration of lenders
        oneDV2 = ComposerPlugin.getComposer(Chains.BASE);
    }

    function test_light_lending_compoundV2_deposit_native() external {
        vm.assume(user != address(0));

        address token = address(0);
        uint256 amount = 1.0e18;
        deal(user, amount);

        address cToken = _getCollateralToken(token);

        // Get balances before deposit
        uint256 collateralBefore = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingBefore = user.balance; // IERC20All(token).balanceOf(user);

        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, user, cToken, uint8(CompoundV2Selector.MINT_BEHALF));

        vm.prank(user);
        oneDV2.deltaCompose{value: amount}(d);

        // Get balances after deposit
        uint256 collateralAfter = chain.getCollateralBalance(user, token, lender);
        uint256 underlyingAfter = user.balance; // IERC20All(token).balanceOf(user);

        // Assert collateral balance increased by amount
        assertApproxEqAbs(collateralAfter - collateralBefore, amount, (amount * 9999) / 10000);
        // Assert underlying balance decreased by amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amount, 0);
    }

    function test_light_lending_compoundV2_repay_native() external {
        vm.assume(user != address(0));

        address depositToken = USDC;
        address token = address(0);
        address comptroller = VENUS_COMPTROLLER;

        uint256 amount = 1000000.0e18;
        depositToCompoundV2(depositToken, user, amount, comptroller);

        uint256 amountToBorrow = 10.0e18;
        borrowNativeFromCompoundV2(token, user, amountToBorrow, comptroller);

        uint256 amountToRepay = 7.0e18;

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Repay(token, amountToRepay, user, cToken);

        // Check balances before repay
        uint256 debtBefore = chain.getDebtBalance(user, token, lender);
        uint256 underlyingBefore = user.balance; // IERC20All(token).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose{value: amountToRepay}(d);

        // Check balances after repay
        uint256 debtAfter = chain.getDebtBalance(user, token, lender);
        uint256 underlyingAfter = user.balance; // IERC20All(token).balanceOf(user);

        // Assert debt decreased by repaid amount
        assertApproxEqAbs(debtBefore - debtAfter, amountToRepay, 1);
        // Assert underlying decreased by repaid amount
        assertApproxEqAbs(underlyingBefore - underlyingAfter, amountToRepay, 1);
    }

    function depositToCompoundV2(address token, address userAddress, uint256 amount, address comptroller) internal {
        deal(token, userAddress, amount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = _getCollateralToken(token);

        vm.prank(userAddress);
        IERC20All(comptroller).enterMarkets(cTokens);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        address cToken = _getCollateralToken(token);
        bytes memory d = CalldataLib.encodeCompoundV2Deposit(token, amount, userAddress, cToken, uint8(CompoundV2Selector.MINT_BEHALF));

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    /**
     * native can only be borrowed directly
     */
    function borrowNativeFromCompoundV2(address token, address userAddress, uint256 amountToBorrow, address comptroller) internal {
        vm.prank(userAddress);
        IERC20All(comptroller).updateDelegate(address(oneDV2), true);

        address cToken = _getCollateralToken(token);

        vm.prank(userAddress);
        VenusBorrow(cToken).borrow(amountToBorrow);
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}

interface VenusBorrow {
    function borrow(uint256) external returns (uint256);
}
