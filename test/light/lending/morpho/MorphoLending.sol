// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {MorphoMathLib} from "../utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "../utils/Morpho.sol";
import {SweepType} from "contracts/1delta/modules/light/enums/MiscEnums.sol";
import {OneDeltaComposerLight} from "light/Composer.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/light/utils/CalldataLib.sol";

/**
 * We test all CalldataLib.morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract MorphoBlueTest is BaseTest {
    using MorphoMathLib for uint256;
    using MorphoMathLib for uint128;

    OneDeltaComposerLight oneD;

    uint256 internal constant forkBlock = 26696865;
    uint256 internal constant MORPHO_ID = 0;

    address internal LBTC;
    address internal USDC;
    address internal WETH;

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    MarketParams LBTC_USDC_MARKET;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);

        oneD = new OneDeltaComposerLight();
        // initialize the addresses
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        // initialize the market
        LBTC_USDC_MARKET = MarketParams(
            USDC,
            LBTC,
            0x6E877Ff82A5ED6cB4f4789c27D9F9B1d54388e4F,
            0x46415998764C29aB2a25CbeA6254146D50D22687,
            860000000000000000
        );
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    function encodeMorphoPermit(uint256 nonce, bool allow) private pure returns (bytes memory) {
        uint256 _data = uint160(nonce);
        if (allow) _data = (_data & ~UPPER_BIT) | UPPER_BIT;

        return abi.encodePacked(
            _data,
            uint32(423),
            uint256(674321764327), //
            uint256(943209784329784327982)
        );
    }

    function test_light_lending_morpho_permit() external {
        vm.assume(user != address(0));

        bytes memory d = encodeMorphoPermit(999, true);
        uint16 len = uint16(d.length);

        bytes memory data = abi.encodePacked(
            uint8(ComposerCommands.PERMIT), //
            uint8(PermitIds.ALLOW_CREDIT_PERMIT),
            MORPHO,
            len,
            d
        );

        vm.prank(user);
        vm.expectRevert("invalid nonce");
        oneD.deltaCompose(data);
    }

    function test_light_lending_morpho_withdraw_collateral() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        depositCollateralToMorpho(user, assets);

        uint256 withdrawAssets = 0.5e8;

        (,, uint128 collateralBefore) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        uint256 underlyingBefore = IERC20All(LBTC).balanceOf(user);

        bytes memory withdrawCall = CalldataLib.morphoWithdrawCollateral(
            encodeMarket(LBTC_USDC_MARKET),
            withdrawAssets, //
            user,
            MORPHO
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        (,, uint128 collateralAfter) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        uint256 underlyingAfter = IERC20All(LBTC).balanceOf(user);

        assertApproxEqAbs(collateralAfter, assets - withdrawAssets, 0);
        assertApproxEqAbs(underlyingAfter - underlyingBefore, withdrawAssets, 0);
    }

    function test_light_lending_morpho_borrow() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        uint256 underlyingBefore = IERC20All(borrowAsset).balanceOf(user);

        bytes memory borrowCall = CalldataLib.morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user,
            MORPHO
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        // get market data
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) =
            IMorphoEverything(MORPHO).market(marketId(LBTC_USDC_MARKET));

        (, uint128 borrowShares,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        uint256 borrowBalanceAfter = borrowShares.toAssetsDown(totalBorrowAssets, totalBorrowShares);

        assertEq(borrowBalanceAfter, borrowAssets);
    }

    function test_light_lending_morpho_repay_by_assets() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = CalldataLib.morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user,
            MORPHO
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        bytes memory repayCall = CalldataLib.morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            true,
            borrowAssets, //
            user,
            hex"",
            MORPHO,
            MORPHO_ID
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        (, uint128 borrowShares,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(borrowShares, 0, 1);
    }

    function test_light_lending_morpho_repay_by_shares() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall =
            CalldataLib.morphoBorrow(encodeMarket(LBTC_USDC_MARKET), false, borrowAssets, user, MORPHO);

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        (, uint128 borrowShares,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);

        bytes memory repayCall = CalldataLib.morphoRepay(
            encodeMarket(LBTC_USDC_MARKET), true, false, borrowShares, user, hex"", MORPHO, MORPHO_ID
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        (, uint128 borrowSharesAfter,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(borrowSharesAfter, 0, 1);
    }

    function test_light_lending_morpho_repay_with_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = CalldataLib.morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user,
            MORPHO
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        bytes memory sweepWethInCallback = CalldataLib.sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory repayCall = CalldataLib.morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            true,
            borrowAssets, //
            user,
            sweepWethInCallback,
            MORPHO,
            MORPHO_ID
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        console.logBytes32(marketId(LBTC_USDC_MARKET));
        assertApproxEqAbs(IERC20All(WETH).balanceOf(user), recoverWeth, 0);
    }

    function test_light_lending_morpho_repay_all() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = CalldataLib.morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user,
            MORPHO
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        logMarket(marketId(LBTC_USDC_MARKET));
        logPos(marketId(LBTC_USDC_MARKET), user);

        bytes memory repayCall = CalldataLib.morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            false,
            type(uint112).max, //
            user,
            hex"",
            MORPHO,
            MORPHO_ID
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets + 1 //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        (, uint128 borrowShares,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertEq(borrowShares, 0);

        // console.logBytes32(marketId(LBTC_USDC_MARKET));
        logPos(marketId(LBTC_USDC_MARKET), user);
    }

    function test_light_lending_morpho_deposit_loan_asset() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address loan = USDC;
        bytes memory transferTo = CalldataLib.transferIn(
            loan,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.morphoDeposit(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            assets,
            user,
            hex"", //,
            MORPHO,
            MORPHO_ID
        );
        vm.prank(user);
        IERC20All(loan).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (uint256 supplyShares,,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);

        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares, //
            ,
            ,
            ,
        ) = IMorphoEverything(MORPHO).market(marketId(LBTC_USDC_MARKET));

        uint256 assetsSupplied = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        assertApproxEqAbs(assetsSupplied, assets - 1, 0);
    }

    function test_light_lending_morpho_deposit_loan_asset_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);
        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address loan = USDC;
        bytes memory transferTo = CalldataLib.transferIn(
            loan,
            address(oneD),
            assets //
        );

        bytes memory sweepWethInCallback = CalldataLib.sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory deposit = CalldataLib.morphoDeposit(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            assets,
            user,
            sweepWethInCallback,
            MORPHO, //
            MORPHO_ID
        );
        vm.prank(user);
        IERC20All(loan).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (uint256 supplyShares,,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);

        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares, //
            ,
            ,
            ,
        ) = IMorphoEverything(MORPHO).market(marketId(LBTC_USDC_MARKET));

        uint256 assetsSupplied = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        assertApproxEqAbs(assetsSupplied, assets - 1, 0);
        assertApproxEqAbs(IERC20All(WETH).balanceOf(user), recoverWeth, 0);
    }

    function test_light_lending_morpho_withdraw_loan_asset() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 loanAssetAm = 20_000.0e6;
        uint256 loanAssetAmWithdraw = 10_000.0e6;

        address loan = USDC;
        depositToMorpho(user, false, loanAssetAm);

        bytes memory withdrawCall = CalldataLib.morphoWithdraw(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            loanAssetAmWithdraw,
            user,
            MORPHO //
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        uint256 bal = IERC20All(loan).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        uint256 balAfter = IERC20All(loan).balanceOf(user);
        (uint256 supplyShares,,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(balAfter - bal, loanAssetAm - loanAssetAmWithdraw, 0);
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares, //
            ,
            ,
            ,
        ) = IMorphoEverything(MORPHO).market(marketId(LBTC_USDC_MARKET));

        uint256 assetsSupplied = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        assertApproxEqAbs(assetsSupplied, loanAssetAm - loanAssetAmWithdraw - 1, 0);
    }

    function test_light_lending_morpho_withdraw_loan_asset_all() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 loanAssetAm = 20_000.0e6;
        uint256 loanAssetAmWithdraw = type(uint112).max;

        address loan = USDC;
        depositToMorpho(user, false, loanAssetAm);

        bytes memory withdrawCall = CalldataLib.morphoWithdraw(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            loanAssetAmWithdraw,
            user,
            MORPHO //
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        uint256 bal = IERC20All(loan).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        uint256 balAfter = IERC20All(loan).balanceOf(user);
        (uint256 supplyShares,,) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(balAfter - bal, loanAssetAm - 1, 0);

        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares, //
            ,
            ,
            ,
        ) = IMorphoEverything(MORPHO).market(marketId(LBTC_USDC_MARKET));

        uint256 assetsSupplied = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        assertApproxEqAbs(assetsSupplied, 0, 0);
    }

    function test_light_lending_morpho_deposit_collateral() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address collateral = LBTC;
        bytes memory transferTo = CalldataLib.transferIn(
            collateral,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.morphoDepositCollateral(
            encodeMarket(LBTC_USDC_MARKET),
            assets,
            user,
            hex"",
            MORPHO, //
            MORPHO_ID
        );
        vm.prank(user);
        IERC20All(collateral).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (,, uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(assets, collateralAmount, 0);
    }

    function test_light_lending_morpho_deposit_collateral_with_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address collateral = LBTC;
        bytes memory transferTo = CalldataLib.transferIn(
            collateral,
            address(oneD),
            assets //
        );

        bytes memory sweepWethInCallback = CalldataLib.sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory deposit = CalldataLib.morphoDepositCollateral(
            encodeMarket(LBTC_USDC_MARKET),
            assets,
            user,
            sweepWethInCallback,
            MORPHO, //
            MORPHO_ID
        );
        vm.prank(user);
        IERC20All(collateral).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (,, uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(assets, collateralAmount, 0);
        assertApproxEqAbs(IERC20All(WETH).balanceOf(user), recoverWeth, 0);
    }

    function encodeMarket(MarketParams memory m) internal pure returns (bytes memory) {
        return abi.encodePacked(m.loanToken, m.collateralToken, m.oracle, m.irm, uint128(m.lltv));
    }

    function depositCollateralToMorpho(address userAddr, uint256 amount) internal {
        address collateral = LBTC;
        bytes memory transferTo = CalldataLib.transferIn(
            collateral,
            address(oneD),
            amount //
        );

        bytes memory deposit = CalldataLib.morphoDepositCollateral(
            encodeMarket(LBTC_USDC_MARKET),
            amount,
            user,
            hex"",
            MORPHO, //
            MORPHO_ID
        );
        vm.prank(userAddr);
        IERC20All(collateral).approve(address(oneD), type(uint256).max);

        vm.prank(userAddr);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    function depositToMorpho(address userAddr, bool isShares, uint256 amount) internal {
        address loan = USDC;
        bytes memory transferTo = CalldataLib.transferIn(
            loan,
            address(oneD),
            amount //
        );

        bytes memory deposit = CalldataLib.morphoDeposit(
            encodeMarket(LBTC_USDC_MARKET),
            isShares,
            amount,
            userAddr,
            hex"",
            MORPHO, //
            MORPHO_ID
        );
        vm.prank(userAddr);
        IERC20All(loan).approve(address(oneD), type(uint256).max);

        vm.prank(userAddr);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    /// @notice Returns the id of the market `marketParams`.
    function logMarket(bytes32 id) internal view {
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee //
        ) = IMorphoEverything(MORPHO).market(id);
        console.log("totalSupplyAssets", totalSupplyAssets);
        console.log("totalSupplyShares", totalSupplyShares);
        console.log("totalBorrowAssets", totalBorrowAssets);
        console.log("totalBorrowShares", totalBorrowShares);
        console.log("lastUpdate", lastUpdate);
        console.log("fee", fee); //
    }

    /// @notice Returns the id of the market `marketParams`.
    function logPos(bytes32 id, address userAddress) internal view {
        (
            uint256 supplyShares, //
            uint128 borrowShares,
            uint128 collateral
        ) = IMorphoEverything(MORPHO).position(id, userAddress);
        console.log("supplyShares", supplyShares);
        console.log("borrowShares", borrowShares);
        console.log("collateral", collateral);
    }

    /// @notice Returns the id of the market `marketParams`.
    function marketId(MarketParams memory marketParams) internal pure returns (bytes32 marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(marketParams, mul(5, 32))
        }
    }
}
