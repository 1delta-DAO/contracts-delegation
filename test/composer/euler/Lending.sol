// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
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
contract EulerLendingTest is BaseTest {
    using CalldataLib for bytes;

    IComposerLike oneD;

    uint256 internal constant forkBlock = 0;

    // address internal USDC;
    address internal WETH;
    // address internal constant USDC_VAULT = 0xe0a80d35bB6618CBA260120b279d357978c42BCE;
    address internal constant SUSDE_VAULT = 0x498c014dE23f19700F51e85a384AB1B059F0672e;
    address internal constant USDC_VAULT = 0x9bD52F2805c6aF014132874124686e7b248c2Cbb;

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address internal SUSDE;
    address internal USDC;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        SUSDE = chain.getTokenAddress(Tokens.SUSDE);
        USDC = chain.getTokenAddress(Tokens.USDC);

        oneD = ComposerPlugin.getComposer(chainName);
    }

    function test_light_euler_deposit() external {
        deal(USDC, user, 300_000.0e6);

        address vault = USDC_VAULT;
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
        address vault = USDC_VAULT;

        uint256 desiredShares = 10.0e8;

        uint256 assets = IERC20All(USDC_VAULT).convertToAssets(desiredShares);

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
            USDC_VAULT, //
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
        address vault = USDC_VAULT;

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
}
