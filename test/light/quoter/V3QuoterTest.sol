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
    address internal USDC;

    address internal WETH_USDC_500_POOL;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);

        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);

        quoter = new QuoterLight();
        composer = new OneDeltaComposerLight();

        WETH_USDC_500_POOL = IF(UNI_FACTORY).getPool(WETH, USDC, 500);

        deal(WETH, address(this), 10 ether);
        deal(USDC, address(this), 10000 * 1e6);

        // Approve composer
        IERC20(WETH).approve(address(composer), type(uint256).max);
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
        uint256 amountIn = 1 * 1e18; // 1 WETH

        bytes memory swapHead = CalldataLib.swapHead(amountIn, 0, WETH, false);
        bytes memory swapBranch = swapBranch(0, 0, ""); //(0,0)
        bytes memory swapCall = CalldataLib.uniswapV3StyleSwap(
            abi.encodePacked(swapHead, swapBranch),
            USDC,
            address(this),
            0,
            WETH_USDC_500_POOL,
            500,
            CalldataLib.DexPayConfig.CONTRACT_PAYS,
            ""
        );
        // Use utility function to encode path
        bytes memory path = uniswapV3StyleSwap(
            USDC, address(this), 0, WETH_USDC_500_POOL, 500, CalldataLib.DexPayConfig.CONTRACT_PAYS, new bytes(0)
        );
        // Get quote
        uint256 quotedAmountOut = quoter.quote(abi.encodePacked(swapBranch, path));

        // Get actual amount from a real swap
        uint256 balanceBefore = IERC20(USDC).balanceOf(address(this));

        composer.deltaCompose(swapCall);

        uint256 balanceAfter = IERC20(USDC).balanceOf(address(this));
        uint256 actualAmountOut = balanceAfter - balanceBefore;

        // Compare results
        assertApproxEqRel(quotedAmountOut, actualAmountOut, 0.01e18, "didn't work");
        console.log("Quote amount:", quotedAmountOut);
        console.log("Actual amount:", actualAmountOut);
    }
}
