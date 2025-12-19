// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4626Deposit, encodeErc4646Withdraw
 */
contract SwapSplitTest is BaseTest {
    uint8 internal UNISWAP_V3_DEX_ID = 0;
    uint8 internal IZUMI_DEX_ID = 49;

    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    uint256 internal constant forkBlock = 26696865;
    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant KEYCAT = 0x9a26F5433671751C3276a065f57e5a02D2817973;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3
    // 33% USDC ---uni----> WETH
    // 33% USDC ---izi----> WETH
    // 33% USDC ---uni----> WETH
    function v3poolSplitSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint16 fee2,
        uint16 fee3,
        address receiver,
        uint256 amount
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1),
            //
            assetIn,
            uint8(0), // swaps max index
            uint8(2), // splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );

        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            // v3 pool data
            pool,
            uint8(DexForkMappings.UNISWAP_V3), // <- the actual uni v3
            fee,
            uint16(0) // cll length
        ); //
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(DexTypeMappings.IZI_ID),
            // v3 pool data
            pool,
            uint8(DexForkMappings.IZI), // <- the actual izumi
            fee2,
            uint16(0) // cll length
        ); //
        pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            // v3 pool data
            pool,
            uint8(DexForkMappings.UNISWAP_V3), // <- the actual uni v3
            fee3,
            uint16(0) // cll length
        ); //
    }

    function test_integ_swap_v3_splits_only() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        uint16 fee3 = 3000;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = v3poolSplitSwap(
            tokenIn,
            tokenOut,
            fee,
            fee2,
            fee3,
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }
}
