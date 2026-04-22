// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";

interface IFluidVaultT2 {
    function operate(
        uint256 nftId,
        int256 newColToken0,
        int256 newColToken1,
        int256 colSharesMinMax,
        int256 newDebt,
        address to
    )
        external
        payable
        returns (uint256, int256, int256);

    function operatePerfect(
        uint256 nftId,
        int256 perfectColShares,
        int256 colToken0MinMax,
        int256 colToken1MinMax,
        int256 newDebt,
        address to
    )
        external
        payable
        returns (uint256, int256[] memory);
}

interface IFluidVaultFactory {
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/**
 * @notice Integration tests for FluidSmartLending against a T2 vault on Ethereum mainnet.
 * @dev Vault `0xf7FA55D14C71241e3c970E30C509Ff58b5f5D557` has cbBTC/WBTC smart collateral and
 *      USDT simple debt. Token ordering (col0 = cbBTC, col1 = WBTC) follows the vault's name.
 */
contract FluidLendingSmartT2Test is BaseTest {
    IComposerLike internal composer;

    address internal constant VAULT = 0xf7FA55D14C71241e3c970E30C509Ff58b5f5D557;
    address internal constant VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;

    address internal cbBTC; // smart col token0
    address internal WBTC; // smart col token1
    address internal USDT; // simple debt

    uint256 internal constant COL0_AMOUNT = 0.02e8; // 0.02 cbBTC
    uint256 internal constant COL1_AMOUNT = 0.02e8; // 0.02 WBTC
    uint256 internal constant DEBT_AMOUNT = 500e6; // 500 USDT

    function setUp() public {
        _init(Chains.ETHEREUM_MAINNET, 0, true);
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        WBTC = chain.getTokenAddress(Tokens.WBTC);
        USDT = chain.getTokenAddress(Tokens.USDT);

        vm.label(address(composer), "Composer");
        vm.label(VAULT, "FluidT2_cbBTC_WBTC_USDT");
        vm.label(cbBTC, "cbBTC");
        vm.label(WBTC, "WBTC");
        vm.label(USDT, "USDT");
    }

    // ─── helpers ───────────────────────────────────────────────────────────

    /// @dev Open a T2 position from `owner_` directly against the vault; NFT minted to owner_.
    function _openPositionDirect(address owner_) internal returns (uint256 nftId) {
        deal(cbBTC, owner_, COL0_AMOUNT);
        deal(WBTC, owner_, COL1_AMOUNT);
        vm.startPrank(owner_);
        IERC20All(cbBTC).approve(VAULT, type(uint256).max);
        IERC20All(WBTC).approve(VAULT, type(uint256).max);
        (nftId,,) = IFluidVaultT2(VAULT).operate(
            0,
            int256(COL0_AMOUNT),
            int256(COL1_AMOUNT),
            int256(1), // min shares — loose for testing
            int256(DEBT_AMOUNT),
            owner_
        );
        vm.stopPrank();
        require(nftId != 0, "open T2 failed");
    }

    // ─── 1. Open balanced position via composer (pull tokens from user, deposit + borrow) ──

    function test_fluid_smart_t2_open_balanced_position_and_sweep() public {
        deal(cbBTC, user, COL0_AMOUNT);
        deal(WBTC, user, COL1_AMOUNT);
        vm.startPrank(user);
        IERC20All(cbBTC).approve(address(composer), type(uint256).max);
        IERC20All(WBTC).approve(address(composer), type(uint256).max);
        vm.stopPrank();

        address[4] memory tokens;
        tokens[0] = cbBTC;
        tokens[1] = WBTC;
        int256[4] memory amounts;
        amounts[0] = int256(COL0_AMOUNT);
        amounts[1] = int256(COL1_AMOUNT);
        amounts[2] = int256(1); // min shares
        amounts[3] = int256(DEBT_AMOUNT);

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 usdtBefore = IERC20All(USDT).balanceOf(user);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeTransferIn(cbBTC, address(composer), COL0_AMOUNT),
            CalldataLib.encodeTransferIn(WBTC, address(composer), COL1_AMOUNT),
            CalldataLib.encodeApprove(cbBTC, VAULT),
            CalldataLib.encodeApprove(WBTC, VAULT),
            // nftReceiver = user → auto-sweep freshly-minted NFT via returned nftId_.
            CalldataLib.encodeFluidSmartOperateT2(0, 0, user, user, VAULT, tokens, amounts)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertEq(IERC20All(USDT).balanceOf(user) - usdtBefore, DEBT_AMOUNT, "user received borrow");
        assertEq(IERC20All(cbBTC).balanceOf(address(composer)), 0, "composer holds no cbBTC");
        assertEq(IERC20All(WBTC).balanceOf(address(composer)), 0, "composer holds no WBTC");
    }

    // ─── 2. Open using FLUID_SMART_USE_BALANCE sentinel (simulates swap → deposit all) ───

    function test_fluid_smart_t2_open_with_balance_sentinel() public {
        // Pre-fund composer to simulate a post-swap state. The composer now "already holds"
        // cbBTC and WBTC; the sentinel tells the op to size the deposit to the balance.
        deal(cbBTC, address(composer), COL0_AMOUNT);
        deal(WBTC, address(composer), COL1_AMOUNT);

        address[4] memory tokens;
        tokens[0] = cbBTC;
        tokens[1] = WBTC;
        int256[4] memory amounts;
        amounts[0] = CalldataLib.FLUID_SMART_USE_BALANCE;
        amounts[1] = CalldataLib.FLUID_SMART_USE_BALANCE;
        amounts[2] = int256(1);
        amounts[3] = int256(DEBT_AMOUNT);

        uint256 nftsBefore = IFluidVaultFactory(VAULT_FACTORY).balanceOf(user);
        uint256 usdtBefore = IERC20All(USDT).balanceOf(user);

        bytes memory data = abi.encodePacked(
            CalldataLib.encodeApprove(cbBTC, VAULT),
            CalldataLib.encodeApprove(WBTC, VAULT),
            CalldataLib.encodeFluidSmartOperateT2(0, 0, user, user, VAULT, tokens, amounts)
        );

        vm.prank(user);
        composer.deltaCompose(data);

        assertEq(IFluidVaultFactory(VAULT_FACTORY).balanceOf(user) - nftsBefore, 1, "user got new NFT");
        assertEq(IERC20All(USDT).balanceOf(user) - usdtBefore, DEBT_AMOUNT, "user received borrow");
        assertEq(IERC20All(cbBTC).balanceOf(address(composer)), 0, "composer cbBTC consumed");
        assertEq(IERC20All(WBTC).balanceOf(address(composer)), 0, "composer WBTC consumed");
    }

    // ─── 3. NFT-custody: borrow more (debt-only operate on an existing position) ───

    function test_fluid_smart_t2_nft_custody_borrow_more() public {
        uint256 nftId = _openPositionDirect(user);

        // Col slots zeroed → no col change; colSharesMinMax also 0 (Fluid requires matching
        // zeros on both axes of the smart side when untouched).
        address[4] memory tokens;
        int256[4] memory amounts;
        amounts[0] = int256(0);
        amounts[1] = int256(0);
        amounts[2] = int256(0);
        amounts[3] = int256(100e6); // +100 USDT borrow

        // No sweep op — the custody callback unconditionally returns the NFT to `from`.
        bytes memory innerOps = CalldataLib.encodeFluidSmartOperateT2(0, nftId, user, address(0), VAULT, tokens, amounts);

        uint256 usdtBefore = IERC20All(USDT).balanceOf(user);
        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertEq(IERC20All(USDT).balanceOf(user) - usdtBefore, 100e6, "borrowed 100 USDT");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back to user");
        assertEq(IERC20All(USDT).balanceOf(address(composer)), 0, "composer holds no USDT");
    }

    // ─── 4. NFT-custody: full close via operatePerfect ───
    //
    // operatePerfect T2 amount layout: [perfectColShares, colToken0MinMax, colToken1MinMax, newDebt].
    //   perfectColShares = int.min ⇒ burn ALL col shares
    //   both MinMax < 0            ⇒ withdraw BOTH tokens, magnitude = min expected out
    //   newDebt          = int.min ⇒ repay ALL debt (simple side sentinel, same as T1)
    //
    // NOTE: amount slots are laid out with `perfectColShares` in slot 0. That slot holds
    // `type(int256).min` — which is the distinct bit pattern from `FLUID_SMART_USE_BALANCE`
    // (`type(int256).max`), so no sentinel collision.

    /// @dev Build the operatePerfect T2 close payload. Extracted so the test body stays under
    ///      the Yul runtime-stack budget (5 `abi.encodePacked` args + 6+ locals in a single
    ///      function pushes above the DUP-accessible 16 slots).
    function _encodeT2Close(uint256 nftId, uint256 usdtBuffer) internal view returns (bytes memory) {
        address[4] memory tokens;
        int256[4] memory amounts;
        amounts[0] = type(int256).min;
        amounts[1] = -int256(1);
        amounts[2] = -int256(1);
        amounts[3] = type(int256).min;
        return CalldataLib.encodeFluidSmartOperatePerfectT2(0, nftId, user, address(0), VAULT, tokens, amounts);
    }

    function test_fluid_smart_t2_nft_custody_full_close_operate_perfect() public {
        uint256 nftId = _openPositionDirect(user);
        uint256 usdtBuffer = DEBT_AMOUNT * 101 / 100;
        deal(USDT, user, usdtBuffer);
        // USDT's `approve` returns no bool — IERC20All's typed interface panics on the empty
        // return data, so use a low-level call here.
        vm.prank(user);
        (bool ok,) = USDT.call(abi.encodeWithSignature("approve(address,uint256)", address(composer), type(uint256).max));
        require(ok, "usdt approve failed");

        bytes memory closeCall = _encodeT2Close(nftId, usdtBuffer);
        bytes memory innerOps = abi.encodePacked(
            CalldataLib.encodeTransferIn(USDT, address(composer), usdtBuffer),
            CalldataLib.encodeApprove(USDT, VAULT),
            closeCall,
            CalldataLib.encodeSweep(USDT, user, 0, SweepType.VALIDATE)
            // NFT returned by the callback — no explicit sweep.
        );

        uint256 cbBefore = IERC20All(cbBTC).balanceOf(user);
        uint256 wbBefore = IERC20All(WBTC).balanceOf(user);

        vm.prank(user);
        IFluidVaultFactory(VAULT_FACTORY).safeTransferFrom(user, address(composer), nftId, innerOps);

        assertGt(IERC20All(cbBTC).balanceOf(user) - cbBefore, 0, "cbBTC returned");
        assertGt(IERC20All(WBTC).balanceOf(user) - wbBefore, 0, "WBTC returned");
        assertEq(IERC20All(USDT).balanceOf(address(composer)), 0, "composer USDT swept");
        assertEq(IFluidVaultFactory(VAULT_FACTORY).ownerOf(nftId), user, "nft swept back");
    }
}
