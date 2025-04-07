// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../../contracts/1delta/modules/light/quoter/QuoterLight.sol";
import "../../../contracts/1delta/modules/light/Composer.sol";
import "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import {DexTypeMappings} from "../../../contracts/1delta/modules/light/swappers/dex/DexTypeMappings.sol";
import {CalldataLib} from "../utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
}

contract V3QuoterTest is BaseTest {
    uint256 internal constant forkBlock = 28493852;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    QuoterLight quoter;
    OneDeltaComposerLight composer;

    address internal WETH;
    address internal cbETH;
    address internal USDC;

    address internal WETH_USDC_500_POOL;
    address internal USDC_CBETH_500_POOL;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);

        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        quoter = new QuoterLight();
        composer = new OneDeltaComposerLight();

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
     * CALLDATA UTILS
     * TODO: could be moved to calldatalib
     */
    function swapBranch(uint256 hops, uint256 splits, bytes memory splitsData) internal pure returns (bytes memory) {
        if (hops != 0 && splits != 0) revert("Invalid branching");
        if (splitsData.length > 0 && splits == 0) revert("No splits but split data provided");
        return abi.encodePacked(uint8(hops), uint8(splits), splitsData);
    }

    function uniswapV3StyleSwap(
        address tokenOut,
        address receiver,
        uint256 forkId,
        address pool,
        uint256 feeTier, //
        CalldataLib.DexPayConfig cfg,
        bytes memory flashCalldata
    ) internal pure returns (bytes memory data) {
        if (uint256(cfg) < 2 && flashCalldata.length > 2) revert("Invalid config for v3 swap");
        data = abi.encodePacked(
            tokenOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            pool,
            uint8(forkId),
            uint16(feeTier), // fee tier to validate pool
            uint16(cfg == CalldataLib.DexPayConfig.FLASH ? flashCalldata.length : uint256(cfg)), //
            bytes(cfg == CalldataLib.DexPayConfig.FLASH ? flashCalldata : new bytes(0))
        );
    }

    /**
     * END OF CALLDATA UTILS
     */
    function test_light_quoter_simple_swap() public {
        /**
         * WETH -> USDC (0,0)
         */
        uint256 amountIn = 1 * 1e18; // 1 WETH

        // Use utility function to encode path
        bytes memory path = uniswapV3StyleSwap(
            USDC, address(quoter), 0, WETH_USDC_500_POOL, 500, CalldataLib.DexPayConfig.CALLER_PAYS, new bytes(0)
        );
        // single swap branch (0,0)
        bytes memory swapBranch = swapBranch(0, 0, ""); //(0,0)

        // Get quote
        uint256 quotedAmountOut = quoter.quote(abi.encodePacked(uint128(amountIn), uint128(0), WETH, swapBranch, path));

        console.log("Quoted amount:", quotedAmountOut);

        // add quotedAmountOut as amountOutMin
        bytes memory swapHead = CalldataLib.swapHead(amountIn, quotedAmountOut, WETH, false);
        bytes memory swapCall = CalldataLib.uniswapV3StyleSwap(
            abi.encodePacked(swapHead, swapBranch),
            USDC,
            user,
            0,
            WETH_USDC_500_POOL,
            500,
            CalldataLib.DexPayConfig.CALLER_PAYS,
            ""
        );

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(USDC).balanceOf(address(user));

        vm.prank(user);
        composer.deltaCompose(abi.encodePacked(swapCall));

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(user));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }

    function multiPath(address[] memory assets, uint16[] memory fees, address receiver)
        internal
        view
        returns (bytes memory data)
    {
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
                uint16(CalldataLib.DexPayConfig.CALLER_PAYS),
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
        uint256 quotedAmountOut = quoter.quote(abi.encodePacked(uint128(amountIn), uint128(0), USDC, path));

        console.log("Quoted amount:", quotedAmountOut);

        // actual swap,  pass in the quote
        bytes memory swapHead = CalldataLib.swapHead(amountIn, quotedAmountOut, USDC, false);

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
}
