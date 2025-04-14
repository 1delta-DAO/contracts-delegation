// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract SwapsSplitsAndHopsLightTest is BaseTest {
    uint8 internal UNISWAP_V3_DEX_ID = 0;
    uint8 internal IZUMI_DEX_ID = 49;
    uint8 internal UNISWAP_V2_DEX_ID = 100;
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
        
        _init(chainName, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function multiPath(
        address[] memory assets,
        uint16[] memory fees,
        uint8[] memory dexIds,
        address receiver
    ) internal view returns (bytes memory data) {
        printPath(assets);
        data = abi.encodePacked(
            uint8(fees.length - 1), // path max index
            uint8(0) // no splits
        );
        for (uint i = 0; i < assets.length - 1; i++) {
            address pool;
            if (dexIds[i] == DexTypeMappings.UNISWAP_V3_ID) {
                pool = IF(UNI_FACTORY).getPool(assets[i], assets[i + 1], fees[i]);
            } else {
                pool = IF(IZI_FACTORY).pool(assets[i], assets[i + 1], fees[i]);
            }
            console.log("multiPath pool", pool, dexIds[i], assets[i] < assets[i + 1]);
            address _receiver = i < assets.length - 2 ? address(oneDV2) : receiver;
            if (i == 0) {
                data = abi.encodePacked(
                    data, //
                    uint16(0), // atomic
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
                    uint8(0), // <-- we assume native protocol here
                    fees[i],
                    uint16(0)
                );
            } else {
                data = abi.encodePacked(
                    data, //
                    uint16(0), // atomic
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
                    uint8(0), // <-- we assume native protocol here
                    fees[i],
                    uint16(1)
                );
            }
        }
    }

    function printPath(address[] memory assets) internal view {
        console.log("-----------------------------");
        for (uint i = 0; i < assets.length; i++) {
            console.log("          |         ");
            console.log(IERC20All(assets[i]).symbol(), assets[i]);
            if (i < assets.length - 1) console.log("          |         ");
        }
        console.log("-----------------------------");
    }

    function getPath_USDC_WETH()
        internal
        view
        returns (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        )
    {
        assets = new address[](3);
        fees = new uint16[](2);
        dexIds = new uint8[](2);
        assets[0] = USDC;
        assets[1] = cbBTC;
        assets[2] = WETH;
        fees[0] = 500;
        fees[1] = 3000;
        dexIds[0] = uint8(DexTypeMappings.UNISWAP_V3_ID);
        dexIds[1] = uint8(DexTypeMappings.UNISWAP_V3_ID);
    }

    function get_USDC_WETH_MultiPathCalldata(
        address receiver //
    ) internal view returns (bytes memory data) {
        (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        ) = getPath_USDC_WETH();

        data = multiPath(
            assets,
            fees,
            dexIds,
            receiver //
        );
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3 based route
    // 33% USDC ---uni----> WETH
    // 33% USDC ---izi----> WETH
    // 33% USDC -> cbBTC -> WETH  /// the last ones are all uni V3
    function v3poolpSwapWithRoute(uint16 fee, uint16 fee2, address receiver, uint256 amount) internal view returns (bytes memory data) {
        address assetIn = USDC;
        address assetOut = WETH;
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1), //
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
            get_USDC_WETH_MultiPathCalldata(receiver) //
        ); //
    }

    function test_light_swap_v3_splits_with_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        deal(tokenIn, user, 100.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        bytes memory swap = v3poolpSwapWithRoute(
            fee,
            fee2,
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }
}
