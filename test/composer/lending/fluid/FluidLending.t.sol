// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

interface IFluidVaultT1 {
    function operate(
        uint256 nftId,
        int256 newCol,
        int256 newDebt,
        address to
    )
        external
        payable
        returns (uint256 nftId_, int256 finalCol, int256 finalDebt);
}

interface IFluidVaultFactory {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @notice Integration tests for FluidLending against the Fluid ETH-USDC vault on Ethereum mainnet.
 * @dev Vault `0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3` is a T1 vault with ETH collateral,
 *      USDC debt. Tests run against a forked mainnet via the BaseTest harness.
 */
contract FluidLendingTest is BaseTest {
    IComposerLike internal composer;

    /// @dev Fluid ETH-USDC vault (T1) on Ethereum mainnet.
    address internal constant VAULT = 0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3;
    /// @dev Fluid VaultFactory (ERC721 holding all position NFTs) on Ethereum mainnet.
    address internal constant VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;
    /// @dev USDC on Ethereum mainnet.
    address internal USDC;

    /// @dev Composer's freshly-deployed CREATE address on mainnet may already hold a few wei of
    ///      ETH (an existing contract account at the same address). All composer-balance assertions
    ///      compare against the snapshot taken in setUp() instead of literal zero.
    uint256 internal composerEthBaseline;

    function setUp() public {
        // Latest block — the vault is long-deployed; pin via env if determinism is needed.
        _init(Chains.ETHEREUM_MAINNET, 0, true);
        USDC = chain.getTokenAddress(Tokens.USDC);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);

        composerEthBaseline = address(composer).balance;

        vm.label(address(composer), "Composer");
        vm.label(VAULT, "FluidEthUsdcVault");
        vm.label(VAULT_FACTORY, "FluidVaultFactory");
        vm.label(USDC, "USDC");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Open a fresh ETH/USDC position from `owner_` directly against the vault. NFT is
    ///      minted to `owner_` (msg.sender on the vault). Returns the freshly minted nftId.
    function _openPosition(address owner_, uint256 ethCol, uint256 usdcDebt) internal returns (uint256 nftId) {
        vm.prank(owner_);
        (nftId,,) = IFluidVaultT1(VAULT).operate{value: ethCol}(0, int256(ethCol), int256(usdcDebt), owner_);
        require(nftId != 0, "open position failed");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Direct ops on a position the user owns (deposit / repay don't need NFT custody)
    // ─────────────────────────────────────────────────────────────────────────

    function test_fluid_deposit_native_collateral_to_existing_position() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);
        uint256 userEthBefore = user.balance;

        uint256 topUp = 0.5 ether;
        bytes memory data = CalldataLib.encodeFluidDeposit(address(0), uint128(topUp), nftId, address(0), VAULT);

        vm.prank(user);
        composer.deltaCompose{value: topUp}(data);

        // User paid the ETH; composer should retain none (it was forwarded as msg.value to vault).
        assertEq(userEthBefore - user.balance, topUp, "user paid topUp");
        assertEq(address(composer).balance, composerEthBaseline, "composer holds no extra ETH");
        // NFT ownership is unchanged — deposit doesn't require custody.
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "user still owns nft");
    }

    function test_fluid_repay_usdc_to_existing_position() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        uint256 repayAmount = 500e6;
        deal(USDC, user, repayAmount);
        vm.prank(user);
        IERC20All(USDC).approve(address(composer), type(uint256).max);

        bytes memory pull = CalldataLib.encodeTransferIn(USDC, address(composer), repayAmount);
        bytes memory repay = CalldataLib.encodeFluidRepay(USDC, uint128(repayAmount), nftId, user, VAULT);

        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(pull, repay));

        // Composer pulled exactly `repayAmount` and forwarded all of it to the vault.
        assertEq(usdcBefore - IERC20All(USDC).balanceOf(user), repayAmount, "user spent repayAmount");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer holds no USDC");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "user still owns nft");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1b. Open new position via composer + SWEEP_NFT delivery to user
    // ─────────────────────────────────────────────────────────────────────────

    function test_fluid_open_new_position_and_sweep_nft_to_user() public {
        // No NFTs owned by user before the call.
        uint256 userNftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);

        uint256 colAmount = 1 ether;
        uint256 borrowAmount = 800e6;

        // Compose: open position via DEPOSIT with nftId=0 (NFT minted to composer), then sweep
        // that NFT back to the user. Fluid assigns sequential ids so predict the new id as
        // `totalSupply() + 1` and feed it to the sweep op.
        uint256 predictedNftId = IFluidVaultFactory(VAULT_FACTORY).totalSupply() + 1;
        bytes memory open = CalldataLib.encodeFluidDeposit(address(0), uint128(colAmount), 0, address(0), VAULT);
        bytes memory sweep = CalldataLib.encodeSweepNft(VAULT_FACTORY, user, predictedNftId);

        vm.prank(user);
        composer.deltaCompose{value: colAmount}(abi.encodePacked(open, sweep));

        // User received exactly one new NFT.
        uint256 userNftsAfter = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        assertEq(userNftsAfter - userNftsBefore, 1, "user got 1 new NFT");

        // Composer ends with no NFTs of this collection.
        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(address(composer)), 0, "composer holds no NFTs");

        // Sanity-check: the newly-minted NFT actually points at a Fluid position by reading its
        // owner — no revert means it exists and is owned by user.
        uint256 newNftId = IFluidVaultFactory(VAULT_FACTORY).tokenOfOwnerByIndex(user, userNftsAfter - 1);
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(newNftId), user, "user owns the new NFT");
        // Borrow on the new position to confirm it has collateral booked. Hand NFT back to the
        // composer (BORROW requires ownership) with inner ops borrow + sweep-NFT-to-user.
        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeFluidBorrow(USDC, uint128(borrowAmount), newNftId, user, VAULT),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, newNftId)
        );
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);
        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), newNftId, innerOps);
        assertEq(IERC20All(USDC).balanceOf(user) - usdcBefore, borrowAmount, "borrow against fresh position");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(newNftId), user, "nft back with user");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. NFT-custody flow (BORROW / WITHDRAW require composer to be ownerOf)
    // ─────────────────────────────────────────────────────────────────────────

    function test_fluid_nft_custody_borrow_more_and_return() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        uint256 borrowAmount = 200e6;
        // Inner ops: borrow USDC straight to user, then sweep the NFT back to user. The receiver
        // hook will revert if the composer still owns the NFT after these ops.
        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeFluidBorrow(USDC, uint128(borrowAmount), nftId, user, VAULT),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, nftId)
        );

        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertEq(IERC20All(USDC).balanceOf(user) - usdcBefore, borrowAmount, "user received borrow");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back to user");
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer holds no USDC");
    }

    function test_fluid_nft_custody_withdraw_partial_collateral_and_return() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        uint256 withdrawAmount = 0.1 ether;
        // Withdraw native ETH straight to the user via vault.operate's `to_` parameter, then
        // sweep the (still-collateralized) NFT back to user.
        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeFluidWithdraw(address(0), uint128(withdrawAmount), nftId, user, VAULT),
            CalldataLib.encodeSweepNft(VAULT_FACTORY, user, nftId)
        );

        uint256 ethBefore = user.balance;

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertEq(user.balance - ethBefore, withdrawAmount, "user received withdrawn ETH");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back to user");
        assertEq(address(composer).balance, composerEthBaseline, "composer holds no extra ETH");
    }

    function test_fluid_nft_custody_full_close_repay_all_withdraw_all() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        // Pre-fund the user with USDC plus a buffer for accrued interest, and approve the composer
        // to pull during the inner repay step.
        uint256 fundedUsdc = 1100e6;
        deal(USDC, user, fundedUsdc);
        vm.prank(user);
        IERC20All(USDC).approve(address(composer), type(uint256).max);

        // Inner ops:
        //   1. pull USDC from user into composer
        //   2. repay-all on the vault (Fluid sentinel: settles the exact debt at execution time)
        //   3. withdraw-all collateral straight to user
        //   4. sweep any leftover USDC back to user (the repay buffer)
        //   5. sweep the (now-empty) position NFT back to user — required, the receiver hook
        //      reverts if the composer still owns the NFT after the inner dispatch
        bytes memory pull = CalldataLib.encodeTransferIn(USDC, address(composer), fundedUsdc);
        bytes memory repayAll = CalldataLib.encodeFluidRepay(USDC, CalldataLib.FLUID_MAX_AMOUNT, nftId, address(0), VAULT);
        bytes memory withdrawAll = CalldataLib.encodeFluidWithdraw(address(0), CalldataLib.FLUID_MAX_AMOUNT, nftId, user, VAULT);
        bytes memory sweepUsdc = CalldataLib.encodeSweep(USDC, user, 0, SweepType.VALIDATE);
        bytes memory sweepNft = CalldataLib.encodeSweepNft(VAULT_FACTORY, user, nftId);
        bytes memory innerOps = abi.encodePacked(pull, repayAll, withdrawAll, sweepUsdc, sweepNft);

        uint256 ethBefore = user.balance;
        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        // Position fully unwound:
        // - All ETH collateral comes back (allow tiny rounding).
        assertApproxEqAbs(user.balance - ethBefore, 1 ether, 1e6, "ETH collateral fully withdrawn");
        // - User spent only the actual debt + interest (a slice of fundedUsdc); buffer is swept back.
        uint256 usdcSpent = usdcBefore - IERC20All(USDC).balanceOf(user);
        assertGe(usdcSpent, 1000e6, "spent at least the principal");
        assertLe(usdcSpent, fundedUsdc, "spent at most the funded amount");
        // - Composer is empty.
        assertEq(IERC20All(USDC).balanceOf(address(composer)), 0, "composer holds no USDC");
        assertEq(address(composer).balance, composerEthBaseline, "composer holds no extra ETH");
        // - NFT is back with the user.
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back to user");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Auth — onERC721Received gating
    // ─────────────────────────────────────────────────────────────────────────

    function test_fluid_nft_custody_reverts_when_caller_is_not_factory() public {
        bytes memory innerOps = CalldataLib.encodeFluidBorrow(USDC, 100e6, 1, user, VAULT);

        // Direct call to onERC721Received from a non-factory address must revert (InvalidCaller).
        vm.prank(user);
        vm.expectRevert();
        (bool ok,) = address(composer)
            .call(abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", user, user, uint256(1), innerOps));
        ok; // silence unused warning — vm.expectRevert handles assertion
    }

    function test_fluid_nft_custody_reverts_when_operator_differs_from_owner() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        // User approves a third party (e.g. a UI helper) on the factory.
        address attacker = address(0xBAD);
        vm.prank(user);
        // setApprovalForAll(operator, approved)
        (bool ok,) = VAULT_FACTORY.call(abi.encodeWithSignature("setApprovalForAll(address,bool)", attacker, true));
        require(ok, "approve-for-all failed");

        // Attacker tries to drain the position by initiating the transfer with malicious calldata.
        bytes memory maliciousOps = CalldataLib.encodeFluidBorrow(USDC, 999e6, nftId, attacker, VAULT);
        vm.prank(attacker);
        vm.expectRevert();
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, maliciousOps);

        // NFT must still be with the user — composer's `operator == from` check blocked the attack.
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft not stolen");
    }

    function test_fluid_nft_custody_reverts_when_nft_not_swept_back() public {
        uint256 nftId = _openPosition(user, 1 ether, 1000e6);

        uint256 usdcBefore = IERC20All(USDC).balanceOf(user);

        // Borrow ops but deliberately omit SWEEP_NFT.  The post-check in onERC721Received
        // detects that the composer still owns the NFT and reverts the entire transaction,
        // rolling back the borrow atomically.
        bytes memory innerOps = CalldataLib.encodeFluidBorrow(USDC, 200e6, nftId, user, VAULT);

        vm.prank(user);
        vm.expectRevert();
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        // Both the NFT and the borrowed funds must be untouched — full atomic revert.
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft not stolen");
        assertEq(IERC20All(USDC).balanceOf(user), usdcBefore, "no USDC leaked");
    }
}
