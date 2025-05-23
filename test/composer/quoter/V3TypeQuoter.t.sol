// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "../utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract V3QuoterTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 28493852;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    QuoterLight quoter;
    IComposerLike composer;

    address internal WETH;
    address internal cbETH;
    address internal USDC;

    address internal WETH_USDC_500_POOL;
    address internal USDC_CBETH_500_POOL;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        quoter = new QuoterLight();
        composer = ComposerPlugin.getComposer(chainName);

        WETH_USDC_500_POOL = IF(UNI_FACTORY).getPool(WETH, USDC, 500);
        USDC_CBETH_500_POOL = IF(UNI_FACTORY).getPool(USDC, cbETH, 500);
        deal(WETH, address(user), 10 ether);
        deal(USDC, address(user), 1000e6);

        // Approve composer
        vm.startPrank(user);
        IERC20(WETH).approve(address(composer), type(uint256).max);
        IERC20(USDC).approve(address(composer), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_light_quoter_simple_swap_v3() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 1 * 1e18; // 1 WETH

        // Use utility function to encode path
        bytes memory path =
            CalldataLib.encodeUniswapV3StyleSwap(hex"", USDC, address(quoter), 0, WETH_USDC_500_POOL, 500, DexPayConfig.CALLER_PAYS, new bytes(0));
        // single swap branch (0,0)
        bytes memory swapBranch = (new bytes(0)).attachBranch(0, 0, ""); //(0,0)
        uint256 gas = gasleft();
        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, abi.encodePacked(WETH, swapBranch, path));

        gas = gas - gasleft();
        console.log("gas", gas);

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = CalldataLib.swapHead(amountIn, quotedAmountOut, WETH);
        bytes memory swapCall = CalldataLib.encodeUniswapV3StyleSwap(
            abi.encodePacked(swapHead, swapBranch), USDC, user, 0, WETH_USDC_500_POOL, 500, DexPayConfig.CALLER_PAYS, ""
        );

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(USDC).balanceOf(address(user));

        gas = gasleft();

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(swapCall));

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }

    function multiPath(address[] memory assets, uint16[] memory fees, address receiver) internal view returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(fees.length - 1), // path max index
            uint8(0) // no splits
        );
        for (uint256 i = 0; i < assets.length - 1; i++) {
            address pool = IF(UNI_FACTORY).getPool(assets[i], assets[i + 1], fees[i]);

            address _receiver = i < assets.length - 2 ? address(quoter) : receiver;
            data = abi.encodePacked(
                data, //
                uint8(0),
                uint8(0),
                assets[i + 1], // nextToken
                _receiver,
                uint8(DexTypeMappings.UNISWAP_V3_ID),
                pool,
                uint8(0), // <-- we assume native protocol here
                fees[i],
                uint16(DexPayConfig.CALLER_PAYS),
                new bytes(0)
            );
            // console.log("Path: ", i);
            // console.logBytes(data);
        }

        return data;
    }

    function test_light_quoter_multihop_swap() public {
        /**
         * USDC -> WETH -> cbETH (1,0) - two hops
         */
        uint256 amountIn = 100e6;

        // Create the path for multihop: USDC -> WETH -> cbETH
        address[] memory assets = new address[](3);
        assets[0] = USDC;
        assets[1] = WETH;
        assets[2] = cbETH;

        uint16[] memory fees = new uint16[](2);
        fees[0] = 500;
        fees[1] = 500;

        bytes memory path = multiPath(assets, fees, address(quoter));

        // Get quote
        uint256 quotedAmountOut = quoter.quote(amountIn, abi.encodePacked(USDC, path));

        console.log("Quoted amount:", quotedAmountOut);

        // actual swap,  pass in the quote
        bytes memory swapHead = CalldataLib.swapHead(amountIn, quotedAmountOut, USDC);

        // Create the swap path for the composer
        path = multiPath(assets, fees, user);
        bytes memory swapCall = abi.encodePacked(swapHead, path);

        uint256 balanceBefore = IERC20(cbETH).balanceOf(address(user));

        vm.prank(user);
        composer.deltaCompose(swapCall);

        uint256 balanceAfter = IERC20(cbETH).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "Quote doesn't match actual amount");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }

    function test_light_quoter_split_swap() public {
        /**
         * WETH -> USDC (2 splits with different fees, 50/50)
         */
        uint256 amountIn = 1e18; // 1 WETH

        address pool500 = IF(UNI_FACTORY).getPool(WETH, USDC, 500);
        address pool3000 = IF(UNI_FACTORY).getPool(WETH, USDC, 3000);

        // split branch (0,1) with 2 splits

        bytes memory quotePath = CalldataLib.attachBranch(
            "",
            0,
            1, // splits
            abi.encodePacked((type(uint16).max / 2))
        );

        quotePath = quotePath.attachBranch(0, 0, "");

        quotePath = quotePath.encodeUniswapV3StyleSwap( //
            USDC,
            address(quoter),
            0, //
            pool500,
            500,
            DexPayConfig.CALLER_PAYS,
            ""
        );
        quotePath = quotePath.attachBranch(0, 0, "");
        quotePath = quotePath.encodeUniswapV3StyleSwap( // //
            USDC,
            address(quoter),
            0,
            pool3000,
            3000, //
            DexPayConfig.CALLER_PAYS,
            ""
        );

        // Get quote (attach header manually)
        uint256 quotedAmountOut = quoter.quote(amountIn, abi.encodePacked(WETH, quotePath));

        console.log("Quoted amount:", quotedAmountOut);

        // actual swap

        bytes memory swapPath = CalldataLib.swapHead(amountIn, quotedAmountOut, WETH);

        swapPath = swapPath.attachBranch(
            0,
            1, // splits
            abi.encodePacked((type(uint16).max / 2))
        ); //
        swapPath = swapPath.attachBranch(0, 0, "");
        //
        swapPath = swapPath.encodeUniswapV3StyleSwap(
            USDC,
            user,
            0, //
            pool500,
            500,
            DexPayConfig.CALLER_PAYS,
            ""
        );
        swapPath = swapPath.attachBranch(0, 0, "");
        swapPath = swapPath.encodeUniswapV3StyleSwap( // //
            USDC,
            user,
            0,
            pool3000,
            3000, //
            DexPayConfig.CALLER_PAYS,
            ""
        );

        uint256 balanceBefore = IERC20(USDC).balanceOf(address(user));

        vm.prank(user);
        composer.deltaCompose(swapPath);

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "Quote doesn't match actual amount");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }
}
