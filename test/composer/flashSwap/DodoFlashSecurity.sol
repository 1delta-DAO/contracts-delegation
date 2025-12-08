// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens} from "../../data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {DexPayConfig, DodoSelector} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface DVMFAndPair {
    function _REGISTRY_(address, address, uint256) external view returns (address);

    function getDODOPool(address, address) external view returns (address[] memory);

    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDODOCallee {
    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;
}

/**
 * Mimics a Dodo pool
 */
contract FakePool {
    address internal immutable VICTIM;
    address internal immutable TOKEN;
    address internal immutable TOKEN_OUT;
    address internal immutable attacker;
    uint256 internal immutable INDEX;

    constructor(address victim, address tokenToSteal, address tokenOut, uint256 index) {
        VICTIM = victim;
        TOKEN = tokenToSteal;
        TOKEN_OUT = tokenOut;
        attacker = msg.sender;
        INDEX = index;
    }

    // comply with interface
    function querySellBase(address trader, uint256 payBaseAmount) public view returns (uint256 receiveQuoteAmount, uint256 mtFee) {
        return (100000, 0);
    }

    // comply with interface
    function querySellQuote(address trader, uint256 payQuoteAmount) public view returns (uint256 receiveBaseAmount, uint256 mtFee) {
        return (100000, 0);
    }

    // fake flash loan, tryingto impersonate a pool, injecting a malicious callback
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external {
        /// theft txn that would pull from callerAddress
        bytes memory stealFunds = CalldataLib.encodeTransferIn(TOKEN, attacker, IERC20All(TOKEN).balanceOf(VICTIM));
        // inject a valid callback selecor with victim address
        IDODOCallee(assetTo).DVMFlashLoanCall(
            msg.sender, baseAmount, quoteAmount, abi.encodePacked(VICTIM, TOKEN, TOKEN_OUT, uint16(INDEX), uint16(stealFunds.length), stealFunds)
        );
        // if we reach this, the composer got exploited
        revert("EXPLOITED");
    }
}

contract FlashSwapTestDodoSecurity is BaseTest {
    using CalldataLib for bytes;

    uint256 internal attackerPk = 0xbad0;
    address internal attacker = vm.addr(attackerPk);

    uint256 internal constant forkBlock = 23969720;
    IComposerLike oneDV2;

    address internal constant DVM_FACTORY = 0x72d220cE168C4f361dD4deE5D826a01AD8598f6C;
    address internal constant DODO_WETH_VERI = 0x104E7642eA8f791B747c672aa8e5EBE92f88F3b1;

    uint256 internal constant DODO_WETH_VERI_INDEX = 0;

    address internal WETH;
    address internal constant VERI = 0x8f3470A7388c05eE4e7AF3d01D8C722b0FF52374;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);
        WETH = chain.getTokenAddress(Tokens.WETH);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function dodoPoolWETHVERISwap(
        address tokenIn,
        address tokenOut,
        address receiver,
        address pool,
        uint256 amount,
        uint256 index,
        bool sellBase,
        bytes memory callbackData
    )
        internal
        view
        returns (bytes memory data)
    {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            tokenIn
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeDodoStyleSwap(
            tokenOut,
            receiver,
            pool,
            sellBase ? DodoSelector.SELL_BASE : DodoSelector.SELL_QUOTE, // sell quote
            index,
            DexPayConfig.FLASH, // payMode <- user pays
            callbackData
        );
    }

    // we use a valid flash swap as baseline
    function test_integ_flashSwap_flash_swap_dodo_single_veri() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 1.0e18;
        uint256 approxOut = 228244102762020462043;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);
        bytes memory transfer = CalldataLib.encodeTransferIn(
            tokenIn,
            DODO_WETH_VERI,
            amount //
        );
        bytes memory sweep = CalldataLib.encodeSweep(
            tokenOut,
            user,
            0, //
            SweepType.VALIDATE
        );
        bytes memory swap = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            DODO_WETH_VERI,
            amount, //
            DODO_WETH_VERI_INDEX,
            true,
            abi.encodePacked(transfer, sweep)
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        uint256 gas = gasleft();

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    // we cover the reverse case, too
    function test_integ_flashSwap_flash_swap_dodo_single_veri_reverse() external {
        vm.assume(user != address(0));

        address tokenIn = VERI;
        address tokenOut = WETH;
        uint256 amount = 1.0e18;
        uint256 approxOut = 3243997071385444;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);
        bytes memory transfer = CalldataLib.encodeTransferIn(
            tokenIn,
            DODO_WETH_VERI,
            amount //
        );
        bytes memory sweep = CalldataLib.encodeSweep(
            tokenOut,
            user,
            0, //
            SweepType.VALIDATE
        );
        bytes memory swap = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            DODO_WETH_VERI,
            amount, //
            DODO_WETH_VERI_INDEX,
            false,
            abi.encodePacked(transfer, sweep)
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        uint256 gas = gasleft();

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    /**
     * Exploit attempt: try to call the CB directly to the composer
     */
    function test_security_flashSwap_flash_swap_dodo_caller() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        address pair = DODO_WETH_VERI;
        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidFlashLoan()");
        IDODOCallee(address(oneDV2)).DVMFlashLoanCall(
            address(oneDV2), 10, 10, abi.encodePacked(user, tokenIn, tokenOut, uint16(DODO_WETH_VERI_INDEX), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Exploit attempt: try to trigger the CB on the composer by calling swap with composer as target
     */
    function test_security_flashSwap_flash_swap_dodo_remote_call_to_composer() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        address pair = DODO_WETH_VERI;
        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        DVMFAndPair(pair).flashLoan(
            // caller, base, quote, pId (index) , cdLength, cd
            0,
            90000,
            address(oneDV2),
            abi.encodePacked(user, tokenIn, tokenOut, uint16(DODO_WETH_VERI_INDEX), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * General issue: No fallthrough if wrong index
     */
    function test_security_flashSwap_flash_swap_dodo_bad_index() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 1.0e18;
        uint256 approxOut = 21319114459675017318834;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);
        bytes memory transfer = CalldataLib.encodeTransferIn(
            tokenIn,
            DODO_WETH_VERI,
            amount //
        );
        bytes memory sweep = CalldataLib.encodeSweep(
            tokenOut,
            user,
            0, //
            SweepType.VALIDATE
        );
        bytes memory swap = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            DODO_WETH_VERI,
            amount, //
            2,
            // <- wrong index
            true,
            abi.encodePacked(transfer, sweep)
        );

        vm.prank(user);
        vm.expectRevert("InvalidFlashLoan()");
        oneDV2.deltaCompose(swap);
    }

    /**
     * General issue: no fallthrough if index overflow
     */
    function test_security_flashSwap_flash_swap_dodo_bad_index_out_of_bounds() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 1.0e18;
        uint256 approxOut = 21319114459675017318834;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);
        bytes memory transfer = CalldataLib.encodeTransferIn(
            tokenIn,
            DODO_WETH_VERI,
            amount //
        );
        bytes memory sweep = CalldataLib.encodeSweep(
            tokenOut,
            user,
            0, //
            SweepType.VALIDATE
        );
        bytes memory swap = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            DODO_WETH_VERI,
            amount, //
            999,
            // <- out of bounds index
            true,
            abi.encodePacked(transfer, sweep)
        );

        vm.prank(user);
        vm.expectRevert(); // it reverts with InvalidFEOpcode
        oneDV2.deltaCompose(swap);
    }

    /**
     * Exploit attempt: create fake pool and try re-enter with theft
     */
    function test_security_flashSwap_flash_swap_dodo_scam_pool() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        vm.prank(attacker);
        address fakePool = address(new FakePool(user, tokenIn, tokenOut, DODO_WETH_VERI_INDEX));

        bytes memory badCalldata = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            fakePool, // use the fake pool
            amount, //
            DODO_WETH_VERI_INDEX,
            true,
            abi.encodePacked(uint48(99))
        );

        vm.prank(attacker);
        vm.expectRevert("InvalidFlashLoan()");
        oneDV2.deltaCompose(badCalldata);
    }

    /**
     * Exploit attempt: create fake pool and try re-enter with theft - try fallthrough
     */
    function test_security_flashSwap_flash_swap_dodo_scam_pool_fallthrough() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = VERI;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        vm.prank(attacker);
        address fakePool = address(new FakePool(user, tokenIn, tokenOut, 9099));

        bytes memory badCalldata = dodoPoolWETHVERISwap(
            tokenIn,
            tokenOut,
            address(oneDV2),
            fakePool, // use the fake pool
            amount, //
            999,
            true,
            abi.encodePacked(uint48(99))
        );

        vm.prank(attacker);
        vm.expectRevert();
        oneDV2.deltaCompose(badCalldata);
    }
}
