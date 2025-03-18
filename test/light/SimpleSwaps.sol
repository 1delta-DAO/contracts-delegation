// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "./utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract SwapsLightTest is BaseTest {
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    uint256 internal constant forkBlock = 26696865;
    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal LBTC;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerLight();
    }

    function v3poolSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            assetIn,
            uint8(0), // swaps max index
            uint8(0) // splits
            // single split data (no data here)
            // uint8(0), // swaps max index for inner path
        );
        data = abi.encodePacked(
            data,
            uint8(0), // opType is zero for single swap
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length <- user pays
        );
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3
    function v3poolpSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint16 fee2,
        uint16 fee3,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            assetIn,
            uint8(0), // swaps max index
            uint8(2), // splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );

        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes

        pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            uint8(0),
            // v3 pool data
            pool,
            fee3,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3
    function v3poolUniversalSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint16 fee2,
        uint16 fee3,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            assetIn,
            uint8(0), // swaps max index
            uint8(2), // splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );
        // path
        data = abi.encodePacked(
            data,
            uint8(0), // swaps max index
            uint8(2), // splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );
        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes

        pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint8(0), // pathLength = single swap
            assetOut,
            receiver,
            uint8(0),
            // v3 pool data
            pool,
            fee3,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function multiPath(
        address[] memory assets,
        uint16[] memory fees,
        uint8[] memory dexIds,
        address oneDta,
        address receiver,
        bytes memory dataIn
    ) internal view returns (bytes memory data) {
        printPath(assets);
        data = abi.encodePacked(
            dataIn, //
            uint8(fees.length - 1) // sop type simple
        );
        for (uint i = 0; i < assets.length - 1; i++) {
            address pool;
            if (dexIds[i] == 0) {
                pool = IF(UNI_FACTORY).getPool(assets[i], assets[i + 1], fees[i]);
            } else {
                pool = IF(IZI_FACTORY).pool(assets[i], assets[i + 1], fees[i]);
            }
            console.log("multiPath pool", pool, dexIds[i], assets[i] < assets[i + 1]);
            address _receiver = i < assets.length - 2 ? oneDta : receiver;
            if (i == 0) {
                data = abi.encodePacked(
                    data, //
                    uint8(0), // no splits
                    uint8(0), // no multihop
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
                    fees[i],
                    uint16(0)
                );
            } else {
                data = abi.encodePacked(
                    data, //
                    uint8(0), // no splits
                    uint8(0), // no multihop
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
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

    function getPath()
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
        assets[1] = WETH;
        assets[2] = cbETH;
        fees[0] = 500;
        fees[1] = 500;
        dexIds[0] = 0;
        dexIds[1] = 0;
    }

    function getUSDCWethMultiPathCalldata(
        address oneDta,
        address receiver, //
        bytes memory dataIn
    ) internal view returns (bytes memory data) {
        (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        ) = getPath();

        return
            multiPath(
                assets,
                fees,
                dexIds,
                oneDta,
                receiver,
                dataIn //
            );
    }

    function v3v2poolSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint8(0), // swaps max index
            uint128(amount), //
            assetIn,
            assetOut,
            receiver,
            uint8(0), // splits
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function test_light_swap_v3_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = v3poolSwap(
            tokenIn,
            tokenOut,
            fee,
            uint8(0),
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }

    function test_light_swap_v3_splits() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        uint16 fee3 = 3000;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = v3poolpSwap(
            tokenIn,
            tokenOut,
            fee,
            fee2,
            fee3,
            uint8(0),
            address(oneDV2),
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }

    function test_light_swap_v3_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = getUSDCWethMultiPathCalldata(
            address(oneDV2),
            user,
            abi.encodePacked( //
                uint8(ComposerCommands.SWAPS),
                uint128(amount), //
                tokenIn
            )
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }
}
