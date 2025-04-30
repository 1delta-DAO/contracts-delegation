// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
import "../utils/CalldataLib.sol";
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

    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    QuoterLight quoter;
    IComposerLike composer;

    address internal WETH;
    address internal cbETH;
    address internal USDC;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        composer = ComposerPlugin.getComposer(chainName);

        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        quoter = new QuoterLight();

        deal(WETH, address(user), 10 ether);
        deal(USDC, address(user), 1000e6);

        // Approve composer
        vm.startPrank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        IERC20(USDC).approve(address(composer), type(uint256).max);
        vm.stopPrank();
    }

    function unoV4Swap(address tokenIn, address tokenOut, address receiver) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            tokenIn,
            uint8(0), // swaps max index
            uint8(0) // splits
        ); // swaps max index for inner path
        data = CalldataLib.encodeUniswapV4StyleSwap(
            data,
            tokenOut,
            receiver,
            UNI_V4_PM,
            uint24(500), // fee
            uint24(10), // tick spacing
            address(0), // hook
            hex"", // data length
            DexPayConfig.CALLER_PAYS // caller pays
        );
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_light_quoter_simple_swap_v4() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 1 * 1e18; // 1 WETH

        // Use utility function to encode path
        bytes memory path = unoV4Swap(WETH, USDC, user);

        uint256 gas = gasleft();
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, path);

        gas = gas - gasleft();
        console.log("gas", gas);

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = abi.encodePacked(uint8(ComposerCommands.SWAPS), uint128(amountIn), uint128(1));
        bytes memory swapCall = abi.encodePacked(swapHead, path);

        swapCall = CalldataLib.encodeNextGenDexUnlock(UNI_V4_PM, 0, swapCall);

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(USDC).balanceOf(address(user));

        gas = gasleft();

        vm.prank(user);
        composer.deltaCompose(swapCall);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }
}
