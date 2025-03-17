// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {ComposerLightBaseTest} from "./ComposerLightBaseTest.sol";
import {ChainIds, TokenNames} from "./chain/Lib.sol";
import "./utils/CalldataLib.sol";

/**
 * We test all CalldataLib.morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract ERC4646Test is ComposerLightBaseTest {
    using MorphoMathLib for uint256;

    OneDeltaComposerLight oneD;

    address internal USDC;
    address internal META_MORPHO_USDC;

    address internal MORPHO;

    function setUp() public virtual {
        // initialize the chain
        _init(ChainIds.BASE);

        USDC = chain.getTokenAddress(TokenNames.USDC);
        META_MORPHO_USDC = chain.getTokenAddress(TokenNames.META_MORPHO_USDC);
        MORPHO = chain.getTokenAddress(TokenNames.MORPHO);

        oneD = new OneDeltaComposerLight();
    }

    function test_light_morpho_deposit_to_erc4646() external {
        deal(USDC, user, 300_000.0e6);

        address vault = META_MORPHO_USDC;
        address asset = USDC;

        uint256 assets = 100.0e6;

        bytes memory transferTo = CalldataLib.transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.erc4646Deposit(
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

    function test_light_morpho_deposit_shares_to_erc4646() external {
        deal(USDC, user, 300_000.0e6);

        address asset = USDC;
        address vault = META_MORPHO_USDC;

        uint256 desiredShares = 10.0e8;

        uint256 assets = IERC20All(META_MORPHO_USDC).convertToAssets(desiredShares);

        bytes memory transferTo = CalldataLib.transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.erc4646Deposit(
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
        bytes memory transferTo = CalldataLib.transferIn(
            asset,
            address(oneD),
            assets //
        );

        bytes memory deposit = CalldataLib.erc4646Deposit(
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

    function test_light_morpho_withdraw_from_erc4646() external {
        deal(USDC, user, 300_000.0e6);

        uint256 assets = 100.0e6;
        address underlying = USDC;
        address vault = META_MORPHO_USDC;

        depositToMetaMorpho(user, USDC, assets);

        uint256 withdrawAssets = 70.0e6;
        bytes memory withdrawCall = CalldataLib.erc4646Withdraw(
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

    function test_light_morpho_withdraw_shares_from_erc4646() external {
        deal(USDC, user, 300_000.0e6);

        address underlying = USDC;
        address vault = META_MORPHO_USDC;
        uint256 assets = 100.0e6;

        depositToMetaMorpho(user, underlying, assets);

        uint256 userShares = IERC20All(vault).balanceOf(user);

        bytes memory withdrawCall = CalldataLib.erc4646Withdraw(
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
}
