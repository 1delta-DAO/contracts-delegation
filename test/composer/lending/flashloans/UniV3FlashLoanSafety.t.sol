// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IUniV3FactoryLike {
    function getPool(address, address, uint24) external view returns (address);
}

// solhint-disable max-line-length

/**
 * Integrity & safety of the Uniswap V3-style flash-loan callback.
 * Base has all three families (Classic / Pancake / Algebra), so we exercise them on one fork.
 *
 * Covers:
 *  - valid pools work (Uniswap = family 0, Pancake = family 1)
 *  - only the genuine CREATE2 pool can drive the callback (unauth caller, spoofed tokens, wrong
 *    forkId, wrong family entrypoint all revert BadPool)
 *  - re-entrancy: re-entering the SAME v3 pool is blocked by the pool's own lock, while composing a
 *    DIFFERENT source inside the callback works (that is the whole point of the framework).
 */
contract UniV3FlashLoanSafetyTest is BaseTest {
    IComposerLike internal oneD;
    uint256 internal constant forkBlock = 26696865;

    address internal WETH;
    address internal USDC;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal UNI_POOL; // WETH/USDC 0.05% (forkId 0, family 0)
    uint16 internal constant UNI_FEE = 500;

    // PancakeSwap V3 WETH/USDC fee-100 pool on base (forkId 0, family 1)
    address internal constant PANCAKE_POOL = 0x72AB388E2E2F6FaceF59E3C3FA2C4E29011c2D38;
    uint16 internal constant PANCAKE_FEE = 100;

    uint8 internal constant FORKID_UNISWAP = 0;
    uint8 internal constant FORKID_PANCAKE = 0;

    bytes4 internal constant BAD_POOL = bytes4(keccak256("BadPool()"));

    function setUp() public {
        _init(Chains.BASE, forkBlock, true);
        oneD = ComposerPlugin.getComposer(Chains.BASE);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        (address t0, address t1) = _sorted();
        UNI_POOL = IUniV3FactoryLike(UNI_FACTORY).getPool(t0, t1, UNI_FEE);
        require(UNI_POOL != address(0), "no uni pool");
    }

    function _sorted() internal view returns (address t0, address t1) {
        (t0, t1) = WETH < USDC ? (WETH, USDC) : (USDC, WETH);
    }

    function _feeUp(uint256 amount, uint256 pips) internal pure returns (uint256) {
        return (amount * pips + 1e6 - 1) / 1e6;
    }

    function _repay(address pool, uint256 amountPlusFee) internal view returns (bytes memory) {
        return CalldataLib.encodeSweep(USDC, pool, amountPlusFee, SweepType.AMOUNT);
    }

    // borrow `amount` USDC from `pool`, running `compose` inside the callback
    function _flash(
        uint8 forkId,
        address pool,
        uint16 fee,
        uint256 amount,
        bytes memory compose
    )
        internal
        view
        returns (bytes memory)
    {
        (address t0, address t1) = _sorted();
        uint128 a0 = t0 == USDC ? uint128(amount) : 0;
        uint128 a1 = t1 == USDC ? uint128(amount) : 0;
        return CalldataLib.encodeUniswapV3FlashLoan(forkId, pool, t0, t1, fee, a0, a1, compose);
    }

    // ---------------------------------------------------------------- valid

    function test_univ3_safety_valid_uniswap() external {
        uint256 amount = 100e6;
        uint256 fee = _feeUp(amount, UNI_FEE);
        deal(USDC, address(oneD), fee + 10);
        bytes memory d = _flash(FORKID_UNISWAP, UNI_POOL, UNI_FEE, amount, _repay(UNI_POOL, amount + fee));
        vm.prank(user);
        oneD.deltaCompose(d);
    }

    function test_univ3_safety_valid_pancake() external {
        uint256 amount = 100e6;
        uint256 fee = _feeUp(amount, PANCAKE_FEE);
        deal(USDC, address(oneD), fee + 10);
        bytes memory d = _flash(FORKID_PANCAKE, PANCAKE_POOL, PANCAKE_FEE, amount, _repay(PANCAKE_POOL, amount + fee));
        vm.prank(user);
        oneD.deltaCompose(d);
    }

    // ---------------------------------------------------------------- rejection

    // a caller that is not the genuine pool cannot drive any callback entrypoint
    function test_univ3_safety_unauthorized_caller() external {
        bytes memory junk = _repay(UNI_POOL, 1);
        vm.expectRevert(BAD_POOL);
        oneD.uniswapV3FlashCallback(0, 0, junk);
        vm.expectRevert(BAD_POOL);
        oneD.pancakeV3FlashCallback(0, 0, junk);
        vm.expectRevert(BAD_POOL);
        oneD.algebraFlashCallback(0, 0, junk);
    }

    // calling the REAL uniswap pool but claiming a different token pair -> derived address != caller
    function test_univ3_safety_spoofed_tokens_rejected() external {
        uint256 amount = 100e6;
        deal(USDC, address(oneD), amount);
        address fake = address(0x00000000000000000000000000000000DeaDBeef);
        (address t0, address t1) = WETH < fake ? (WETH, fake) : (fake, WETH);
        bytes memory d = CalldataLib.encodeUniswapV3FlashLoan(
            FORKID_UNISWAP, UNI_POOL, t0, t1, UNI_FEE, uint128(amount), 0, _repay(UNI_POOL, amount)
        );
        vm.prank(user);
        vm.expectRevert(BAD_POOL);
        oneD.deltaCompose(d);
    }

    // a forkId that is not in the family switch hits the default -> BadPool
    function test_univ3_safety_unknown_forkId_rejected() external {
        uint256 amount = 100e6;
        deal(USDC, address(oneD), amount);
        bytes memory d = _flash(99, UNI_POOL, UNI_FEE, amount, _repay(UNI_POOL, amount));
        vm.prank(user);
        vm.expectRevert(BAD_POOL);
        oneD.deltaCompose(d);
    }

    // ---------------------------------------------------------------- re-entrancy

    // re-entering the SAME uniswap pool from inside its own flash is blocked by the pool's lock
    function test_univ3_safety_reenter_same_pool_blocked() external {
        uint256 amount = 100e6;
        uint256 fee = _feeUp(amount, UNI_FEE);
        deal(USDC, address(oneD), 2 * (fee + 10));
        bytes memory inner = _flash(FORKID_UNISWAP, UNI_POOL, UNI_FEE, amount, _repay(UNI_POOL, amount + fee));
        bytes memory outerCompose = abi.encodePacked(inner, _repay(UNI_POOL, amount + fee));
        bytes memory d = _flash(FORKID_UNISWAP, UNI_POOL, UNI_FEE, amount, outerCompose);
        vm.prank(user);
        vm.expectRevert(); // pool reverts "LOK" while locked
        oneD.deltaCompose(d);
    }

    // same as above but for the Pancake family — the pool lock reverts on same-pool re-entry too
    function test_univ3_safety_reenter_same_pool_blocked_pancake() external {
        uint256 amount = 100e6;
        uint256 fee = _feeUp(amount, PANCAKE_FEE);
        deal(USDC, address(oneD), 2 * (fee + 10));
        bytes memory inner = _flash(FORKID_PANCAKE, PANCAKE_POOL, PANCAKE_FEE, amount, _repay(PANCAKE_POOL, amount + fee));
        bytes memory outerCompose = abi.encodePacked(inner, _repay(PANCAKE_POOL, amount + fee));
        bytes memory d = _flash(FORKID_PANCAKE, PANCAKE_POOL, PANCAKE_FEE, amount, outerCompose);
        vm.prank(user);
        vm.expectRevert(); // pancake pool lock reverts while locked
        oneD.deltaCompose(d);
    }

    // composing a DIFFERENT source (pancake) inside a uniswap flash works — cross-pool re-entry is allowed
    function test_univ3_safety_reenter_other_source_works() external {
        uint256 amount = 100e6;
        uint256 uFee = _feeUp(amount, UNI_FEE);
        uint256 pFee = _feeUp(amount, PANCAKE_FEE);
        deal(USDC, address(oneD), uFee + pFee + 20);
        bytes memory inner = _flash(FORKID_PANCAKE, PANCAKE_POOL, PANCAKE_FEE, amount, _repay(PANCAKE_POOL, amount + pFee));
        bytes memory outerCompose = abi.encodePacked(inner, _repay(UNI_POOL, amount + uFee));
        bytes memory d = _flash(FORKID_UNISWAP, UNI_POOL, UNI_FEE, amount, outerCompose);
        vm.prank(user);
        oneD.deltaCompose(d);
    }
}
