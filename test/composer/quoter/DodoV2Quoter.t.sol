// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
import "contracts/utils/CalldataLib.sol";
import {DexPayConfig, DodoSelector} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract V4QuoterTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 28493852;

    address internal constant DODO_WETH_JOJO = 0x0Df758CFe1DE840360a92424494776E8C7f29A9c;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant SUPEROBETH = 0xDBFeFD2e8460a6Ee4955A68582F85708BAEA60A3;
    address internal constant JOJO = 0x0645bC5cDff2376089323Ac20Df4119e48e4BCc4;

    QuoterLight quoter;
    IComposerLike composer;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        quoter = new QuoterLight();
        composer = ComposerPlugin.getComposer(chainName);

        deal(WETH, address(user), 10 ether);
        deal(USDC, address(user), 1000e6);

        // Approve composer
        vm.startPrank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        IERC20(USDC).approve(address(composer), type(uint256).max);
        vm.stopPrank();
    }

    function dodoPoolWETHJOJOSwap(address receiver) internal view returns (bytes memory data) {
        data = abi.encodePacked(WETH);
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeDodoStyleSwap(
            JOJO,
            receiver,
            DODO_WETH_JOJO,
            DodoSelector.SELL_QUOTE, // sell quote
            0,
            DexPayConfig.CALLER_PAYS, // payMode <- user pays
            hex""
        );
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_integ_quoter_simple_dodo() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 1 * 1e18; // 1 WETH

        // Use utility function to encode path
        bytes memory path = dodoPoolWETHJOJOSwap(user);

        uint256 gas = gasleft();
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, path);

        gas = gas - gasleft();
        console.log("gas", gas);

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = abi.encodePacked(uint8(ComposerCommands.SWAPS), uint128(amountIn), uint128(1));
        bytes memory swapCall = abi.encodePacked(swapHead, path);

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(JOJO).balanceOf(address(user));

        gas = gasleft();

        vm.prank(user);
        composer.deltaCompose(swapCall);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balanceAfter = IERC20(JOJO).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }
}
