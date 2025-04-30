// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract BalancerV3QuoterTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 27970029;

    // balancer dex data
    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    address internal constant USDC_WETH_POOL = 0x1667832E66f158043754aE19461aD54D8b178E1E;

    QuoterLight quoter;
    IComposerLike composer;

    address internal WETH;
    address internal cbETH;
    address internal USDC;

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

    function balancerV3Swap(
        address user, //
        address tokenIn,
        address tokenOut
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(tokenIn);
        // no branching
        data = data.attachBranch(0, 0, hex"");
        // attach swap
        data = data.encodeBalancerV3StyleSwap(
            tokenOut,
            user,
            BALANCER_V3_VAULT,
            USDC_WETH_POOL,
            DexPayConfig.CALLER_PAYS,
            hex"" //
        );
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_light_quoter_simple_swap_balancerv3() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 0.05e18;

        // Use utility function to encode path
        bytes memory path = balancerV3Swap(user, WETH, USDC);

        uint256 gas = gasleft();
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, path);

        gas = gas - gasleft();
        console.log("gas", gas);

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = abi.encodePacked(uint8(ComposerCommands.SWAPS), uint128(amountIn), uint128(1));
        bytes memory swapCall = abi.encodePacked(swapHead, path);

        swapCall = CalldataLib.encodeNextGenDexUnlock(BALANCER_V3_VAULT, 0, swapCall);

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
