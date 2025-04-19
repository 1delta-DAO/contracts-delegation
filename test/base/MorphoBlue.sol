// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4646Deposit, encodeErc4646Withdraw
 */
contract MorphoBlueTest is Test, ComposerUtils {
    using MorphoMathLib for uint256;

    OneDeltaComposerBase oneD;

    address internal constant user = address(984327);

    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant META_MORPHO_USDC = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;

    MarketParams LBTC_USDC_MARKET = MarketParams(
        USDC,
        LBTC,
        0x6E877Ff82A5ED6cB4f4789c27D9F9B1d54388e4F,
        0x46415998764C29aB2a25CbeA6254146D50D22687,
        860000000000000000 //
    );

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerBase();
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

    function test_morpho_permit() external {
        vm.assume(user != address(0));

        bytes memory d = encodeMorphoPermit(999, true);
        uint16 len = uint16(d.length);

        bytes memory data = abi.encodePacked(uint8(Commands.EXEC_COMPOUND_V3_PERMIT), MORPHO, len, d);

        vm.prank(user);
        vm.expectRevert("signature expired");
        oneD.deltaCompose(data);
    }

    function test_base_flash_loan_morpho() external {
        address asset = 0x4200000000000000000000000000000000000006;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), 30.0e18);
        uint256 amount = 11111;
        bytes memory dp = sweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );

        bytes memory d = encodeFlashLoan(
            asset,
            amount,
            uint8(254), //
            dp
        );
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.onMorphoFlashLoan(0, d);
    }

    function test_morpho_withdraw_collateral() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        depositCollateralToMorpho(user, assets);

        uint256 withdrawAssets = 0.5e8;
        bytes memory withdrawCall = encodeMorphoWithdrawCollateral(
            encodeMarket(LBTC_USDC_MARKET),
            withdrawAssets, //
            user
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        (,, uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);

        assertApproxEqAbs(collateralAmount, assets - withdrawAssets, 0);
    }

    function test_morpho_borrow() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        uint256 bal = IERC20All(borrowAsset).balanceOf(user);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        uint256 balAf = IERC20All(borrowAsset).balanceOf(user);

        assertApproxEqAbs(balAf - bal, borrowAssets, 0);
        // (, , uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
    }

    function test_morpho_repay() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        bytes memory repayCall = morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            hex""
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        console.logBytes32(marketId(LBTC_USDC_MARKET));
    }

    function test_morpho_repay_with_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        bytes memory sweepWethInCallback = sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory repayCall = morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            sweepWethInCallback
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        console.logBytes32(marketId(LBTC_USDC_MARKET));
        assertApproxEqAbs(IERC20All(WETH).balanceOf(user), recoverWeth, 0);
    }

    function test_morpho_repay_all() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address borrowAsset = USDC;
        uint256 borrowAssets = 30_000.0e6;
        depositCollateralToMorpho(user, assets);

        bytes memory borrowCall = morphoBorrow(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            borrowAssets, //
            user
        );

        vm.prank(user);
        IMorphoEverything(MORPHO).setAuthorization(address(oneD), true);

        vm.prank(user);
        oneD.deltaCompose(borrowCall);

        logMarket(marketId(LBTC_USDC_MARKET));
        logPos(marketId(LBTC_USDC_MARKET), user);

        bytes memory repayCall = morphoRepay(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            type(uint120).max, //
            hex""
        );

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(oneD), type(uint256).max);

        bytes memory transferTo = transferIn(
            borrowAsset,
            address(oneD),
            borrowAssets + 1 //
        );

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, repayCall));

        // console.logBytes32(marketId(LBTC_USDC_MARKET));
        logPos(marketId(LBTC_USDC_MARKET), user);
    }

    function test_morpho_deposit_loan_asset() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address loan = USDC;
        bytes memory transferTo = transferIn(
            loan,
            address(oneD),
            assets //
        );

        bytes memory deposit = encodeMorphoDeposit(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            assets,
            hex"" //
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

    function test_morpho_deposit_loan_asset_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);
        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address loan = USDC;
        bytes memory transferTo = transferIn(
            loan,
            address(oneD),
            assets //
        );

        bytes memory sweepWethInCallback = sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory deposit = encodeMorphoDeposit(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            assets,
            sweepWethInCallback //
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

    function test_morpho_withdraw_loan_asset() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 loanAssetAm = 20_000.0e6;
        uint256 loanAssetAmWithdraw = 10_000.0e6;

        address loan = USDC;
        depositToMorpho(user, false, loanAssetAm);

        bytes memory withdrawCall = encodeMorphoWithdraw(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            loanAssetAmWithdraw,
            user //
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

    function test_morpho_withdraw_loan_asset_all() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 loanAssetAm = 20_000.0e6;
        uint256 loanAssetAmWithdraw = type(uint120).max;

        address loan = USDC;
        depositToMorpho(user, false, loanAssetAm);

        bytes memory withdrawCall = encodeMorphoWithdraw(
            encodeMarket(LBTC_USDC_MARKET),
            false,
            loanAssetAmWithdraw,
            user //
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

    function test_morpho_deposit_collateral() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 1.0e8;

        address collateral = LBTC;
        bytes memory transferTo = transferIn(
            collateral,
            address(oneD),
            assets //
        );

        bytes memory deposit = encodeMorphoDepositCollateral(encodeMarket(LBTC_USDC_MARKET), assets, hex"");
        vm.prank(user);
        IERC20All(collateral).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
        (,, uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);
        assertApproxEqAbs(assets, collateralAmount, 0);
    }

    function test_morpho_deposit_to_meta_morpho() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        address vault = META_MORPHO_USDC;
        address asset = USDC;

        uint256 assets = 100.0e6;

        bytes memory transferTo = transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = encodeErc4646Deposit(
            asset,
            vault, //
            false,
            assets,
            user
        );
        vm.prank(user);
        IERC20All(asset).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));

        uint256 shares = IERC20All(vault).balanceOf(user);
        uint256 assetsInVault = IERC20All(vault).convertToAssets(shares);

        assertApproxEqAbs(assets, assetsInVault, 1); // adjust for rounding
    }

    function test_morpho_deposit_shares_to_meta_morpho() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        address asset = USDC;
        address vault = META_MORPHO_USDC;

        uint256 desiredShares = 10.0e8;

        uint256 assets = IERC20All(META_MORPHO_USDC).convertToAssets(desiredShares);

        bytes memory transferTo = transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = encodeErc4646Deposit(
            asset,
            vault, //
            true,
            desiredShares,
            user
        );
        vm.prank(user);
        IERC20All(asset).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));

        uint256 shares = IERC20All(vault).balanceOf(user);
        uint256 assetsInVault = IERC20All(vault).convertToAssets(shares);

        assertApproxEqAbs(shares, desiredShares, 0); // shares are exact!
        assertApproxEqAbs(assets, assetsInVault, 0);
    }

    function depositToMetaMorpho(address userAddress, address asset, uint256 assets) internal {
        bytes memory transferTo = transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = encodeErc4646Deposit(
            asset,
            META_MORPHO_USDC, //
            false,
            assets,
            userAddress
        );
        vm.prank(userAddress);
        IERC20All(asset).approve(address(oneD), type(uint256).max);

        vm.prank(userAddress);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    function test_morpho_withdraw_from_meta_morpho() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 100.0e6;
        address underlying = USDC;
        address vault = META_MORPHO_USDC;

        depositToMetaMorpho(user, USDC, assets);

        uint256 withdrawAssets = 70.0e6;
        bytes memory withdrawCall = encodeErc4646Withdraw(
            vault, //
            false,
            withdrawAssets,
            user
        );

        vm.prank(user);
        IERC20All(vault).approve(address(oneD), type(uint256).max);

        uint256 underlyingBefore = IERC20All(underlying).balanceOf(user);

        uint256 assetsInVault = IERC20All(vault).convertToAssets(IERC20All(vault).balanceOf(user));

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        uint256 underlyingAfter = IERC20All(underlying).balanceOf(user);
        uint256 assetsInVaultAfter = IERC20All(vault).convertToAssets(IERC20All(vault).balanceOf(user));

        assertApproxEqAbs(assetsInVault - assetsInVaultAfter, withdrawAssets, 1);
        assertApproxEqAbs(underlyingAfter - underlyingBefore, withdrawAssets, 1);
    }

    function test_morpho_withdraw_shares_from_meta_morpho() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        address underlying = USDC;
        address vault = META_MORPHO_USDC;
        uint256 assets = 100.0e6;

        depositToMetaMorpho(user, underlying, assets);

        uint256 userShares = IERC20All(vault).balanceOf(user);

        bytes memory withdrawCall = encodeErc4646Withdraw(
            vault, //
            true,
            userShares / 2,
            user
        );
        vm.prank(user);
        IERC20All(vault).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        assertApproxEqAbs(IERC20All(vault).balanceOf(user), userShares / 2, 0);
    }

    function test_morpho_deposit_collateral_with_callback() external {
        deal(LBTC, user, 30.0e8);
        deal(USDC, user, 300_000.0e6);

        uint256 recoverWeth = 1.0e18;
        deal(WETH, address(oneD), recoverWeth);

        uint256 assets = 1.0e8;

        address collateral = LBTC;
        bytes memory transferTo = transferIn(
            collateral,
            address(oneD),
            assets //
        );

        bytes memory sweepWethInCallback = sweep(
            WETH,
            user,
            recoverWeth,
            SweepType.VALIDATE //
        );

        bytes memory deposit = encodeMorphoDepositCollateral(encodeMarket(LBTC_USDC_MARKET), assets, sweepWethInCallback);
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
        bytes memory transferTo = transferIn(
            collateral,
            address(oneD),
            amount //
        );

        bytes memory deposit = encodeMorphoDepositCollateral(encodeMarket(LBTC_USDC_MARKET), amount, hex"");
        vm.prank(userAddr);
        IERC20All(collateral).approve(address(oneD), type(uint256).max);

        vm.prank(userAddr);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    function depositToMorpho(address userAddr, bool isShares, uint256 amount) internal {
        address loan = USDC;
        bytes memory transferTo = transferIn(
            loan,
            address(oneD),
            amount //
        );

        bytes memory deposit = encodeMorphoDeposit(encodeMarket(LBTC_USDC_MARKET), isShares, amount, hex"");
        vm.prank(userAddr);
        IERC20All(loan).approve(address(oneD), type(uint256).max);

        vm.prank(userAddr);
        oneD.deltaCompose(abi.encodePacked(transferTo, deposit));
    }

    // function test_morpho_balance() external {
    //     deal(LBTC, user, 30.0e8);
    //     deal(USDC, user, 300_000.0e6);

    //     uint loanAssetAm = 1.0e8;

    //     depositCollateralToMorpho(user, loanAssetAm);

    //     (, , uint128 collateralAmount) = IMorphoEverything(MORPHO).position(marketId(LBTC_USDC_MARKET), user);

    //     console.log("collateralAmount", collateralAmount);
    //     address userStored = user;
    //     bytes32 mId = marketId(LBTC_USDC_MARKET);
    //     uint256 am;
    //     uint256 am2;
    //     assembly {
    //         let ptr := mload(0x40)
    //         mstore(ptr, 0x93c5206200000000000000000000000000000000000000000000000000000000)
    //         mstore(add(ptr, 0x4), mId)
    //         mstore(add(ptr, 0x24), userStored)
    //         if iszero(staticcall(gas(), MORPHO, ptr, 0x44, ptr, 0x60)) {
    //             revert(0x0, 0x0)
    //         }
    //         am := and(UINT128_MASK,mload(add(ptr, 0x10)))
    //         am2 :=mload(add(ptr, 0x40))

    //     }
    //     console.log("am", am);
    //     console.log("am2", am2);
    // }

    // function test_base_params() external {
    //     address onBehalf = 0x937Ce2d6c488b361825D2DB5e8A70e26d48afEd5;
    //     uint256 assets = 543978;
    //     uint256 shares = 9753284975432;
    //     MarketParams memory market = MarketParams(
    //         0x4200000000000000000000000000000000000006,
    //         0x4200000000000000000000000000000000000007,
    //         0x4200000000000000000000000000000000000008,
    //         0x4200000000000000000000000000000000000009,
    //         860000000000000000
    //     );

    //     bytes memory dp = sweep(
    //         address(0),
    //         onBehalf,
    //         assets, //
    //         SweepType.AMOUNT
    //     );
    //     console.log(dp.length);
    //     console.logBytes(abi.encodeWithSelector(IMorphoEverything.supplyCollateral.selector, market, assets, onBehalf, dp));
    // }

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
