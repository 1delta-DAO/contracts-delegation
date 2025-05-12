// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {MorphoMathLib} from "test/composer/lending/utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "test/composer/lending/utils/Morpho.sol";

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

/**
 * We test all CalldataLib.morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4646Deposit, encodeErc4646Withdraw
 */
contract ERC4626Test is BaseTest {
    using CalldataLib for bytes;
    using MorphoMathLib for uint256;

    IComposerLike oneD;

    uint256 internal constant forkBlock = 26696865;

    address internal USDC;
    address internal WETH;
    address internal constant META_MORPHO_USDC = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address internal constant USDM = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;
    address internal constant WUSDM = 0x57F5E098CaD7A3D1Eed53991D4d66C45C9AF7812;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneD = ComposerPlugin.getComposer(chainName);
    }

    function test_light_morpho_deposit_to_erc4626() external {
        deal(USDC, user, 300_000.0e6);

        address vault = META_MORPHO_USDC;
        address asset = USDC;

        uint256 assets = 100.0e6;

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.encodeErc4646Deposit(
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

    function test_light_morpho_deposit_shares_to_erc4626() external {
        deal(USDC, user, 300_000.0e6);

        address asset = USDC;
        address vault = META_MORPHO_USDC;

        uint256 desiredShares = 10.0e8;

        uint256 assets = IERC20All(META_MORPHO_USDC).convertToAssets(desiredShares);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.encodeErc4646Deposit(
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
        bytes memory transferTo = CalldataLib.encodeTransferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.encodeErc4646Deposit(
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

    function test_light_morpho_withdraw_from_erc4626() external {
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 100.0e6;
        address underlying = USDC;
        address vault = META_MORPHO_USDC;

        depositToMetaMorpho(user, USDC, assets);

        uint256 withdrawAssets = 70.0e6;
        bytes memory withdrawCall = CalldataLib.encodeErc4646Withdraw(
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

    function test_light_morpho_withdraw_shares_from_erc4626() external {
        deal(USDC, user, 300_000.0e6);

        address underlying = USDC;
        address vault = META_MORPHO_USDC;
        uint256 assets = 100.0e6;

        depositToMetaMorpho(user, underlying, assets);

        uint256 userShares = IERC20All(vault).balanceOf(user);

        bytes memory withdrawCall = CalldataLib.encodeErc4646Withdraw(
            vault, //
            true,
            userShares / 2,
            user
        );
        vm.prank(user);
        IERC20All(vault).approve(address(oneD), type(uint256).max);

        vm.prank(user);
        oneD.deltaCompose(withdrawCall);

        assertApproxEqAbs(IERC20All(vault).balanceOf(user), userShares / 2, 1);
    }

    function wrapSwapWUSDM(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            amount * 105 / 100, // amountOut min
            WUSDM
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWrapperSwap(
            USDM,
            receiver,
            WrapOperation.ERC4626_REDEEM,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function wrapSwapUSDM(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            amount * 8 / 10, // amountOut min
            USDM
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWrapperSwap(
            WUSDM,
            receiver,
            WrapOperation.ERC4626_DEPOSIT,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_wrap_redeem_single() external {
        vm.assume(user != address(0));

        address tokenIn = WUSDM;
        address tokenOut = USDM;
        uint256 amount = 1.0e18;
        uint256 approxOut = 1.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneD), type(uint256).max);

        bytes memory swap = wrapSwapWUSDM(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneD.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    // this one is a bit weird as we
    // forge cannot mint USDM, only WUSDM
    function test_light_wrap_deposit_single() external {
        vm.assume(user != address(0));

        address tokenIn = WUSDM;
        address tokenOut = USDM;
        uint256 amount = 1.0e18;
        uint256 approxOut = 1.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneD), type(uint256).max);

        bytes memory swap = wrapSwapWUSDM(
            user,
            amount //
        );

        vm.prank(user);
        oneD.deltaCompose(swap);

        swap = wrapSwapUSDM(
            user,
            amount //
        );

        tokenIn = USDM;
        tokenOut = WUSDM;
        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneD), type(uint256).max);

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneD.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    function wrapSwapNative(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            address(0)
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWrapperSwap(
            WETH,
            receiver,
            WrapOperation.NATIVE,
            DexPayConfig.PRE_FUND //
        );
    }

    function test_light_wrap_native_single() external {
        vm.assume(user != address(0));

        address tokenOut = WETH;
        uint256 amount = 1.0e18;
        uint256 approxOut = 1.0e18;
        deal(user, amount);

        bytes memory swap = wrapSwapNative(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneD.deltaCompose{value: amount}(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    function wrapSwapWNative(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWrapperSwap(
            address(0),
            receiver,
            WrapOperation.NATIVE,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function test_light_wrap_wnative_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        uint256 amount = 1.0e18;
        uint256 approxOut = 1.0e18;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneD), type(uint256).max);

        bytes memory swap = wrapSwapWNative(
            user,
            amount //
        );

        uint256 balBefore = user.balance;
        vm.prank(user);
        oneD.deltaCompose(swap);

        uint256 balAfter = user.balance;
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
