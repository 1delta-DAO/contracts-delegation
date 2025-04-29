// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig, DodoSelector} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract WooQuoterTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 28493852;

    address internal constant WOO_POOL = 0x5520385bFcf07Ec87C4c53A7d8d65595Dff69FA4;

    address internal USDC;
    address internal DAI;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant WOO_ROUTER = 0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7;

    QuoterLight quoter;
    IComposerLike composer;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock);

        WETH = chain.getTokenAddress(Tokens.WETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        DAI = chain.getTokenAddress(Tokens.DAI);

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

    function wooPoolWETHUSDCSwap(address receiverA, address receiverB) internal view returns (bytes memory data) {
        data = abi.encodePacked(WETH);
        // 1 hop
        data = data.attachBranch(1, 0, hex"");
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWooStyleSwap(
            USDC,
            receiverA,
            WOO_POOL,
            DexPayConfig.CALLER_PAYS // payMode <- user pays
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.encodeWooStyleSwap(
            cbBTC,
            receiverB,
            WOO_POOL,
            DexPayConfig.PRE_FUND // payMode <- user pays
        );
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_light_quoter_simple_woo() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 1 * 1e18; // 1 WETH

        // Use utility function to encode path
        bytes memory path = wooPoolWETHUSDCSwap(WOO_ROUTER, WOO_ROUTER);

        uint256 gas = gasleft();
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, path);

        gas = gas - gasleft();
        console.log("gas", gas);

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = abi.encodePacked(uint8(ComposerCommands.SWAPS), uint128(amountIn), uint128(1));
        bytes memory swapCall = abi.encodePacked(swapHead, wooPoolWETHUSDCSwap(WOO_POOL, user));

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(cbBTC).balanceOf(address(user));

        gas = gasleft();

        vm.prank(user);
        composer.deltaCompose(swapCall);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balanceAfter = IERC20(cbBTC).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }
}
