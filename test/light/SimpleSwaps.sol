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

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract SwapsLightTest is BaseTest {
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    uint256 internal constant forkBlock = 26696865;
    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant KEYCAT = 0x9a26F5433671751C3276a065f57e5a02D2817973;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
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
            uint16(0), // atomic
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); //
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); //

        pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(0),
            // v3 pool data
            pool,
            fee3,
            uint16(0) // cll length
        ); //
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
            if (dexIds[i] == 0) {
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

    function getPath_USDC_CBETH()
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
        dexIds[0] = 0;
        dexIds[1] = 0;
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
    function v3poolpSwapWithRoute(uint16 fee, uint16 fee2, uint8 dexId, address receiver, uint256 amount) internal view returns (bytes memory data) {
        address assetIn = USDC;
        address assetOut = WETH;
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
            uint16(0), // atomic
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); //
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            receiver,
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); //

        pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            get_USDC_WETH_MultiPathCalldata(receiver) //
        ); //
    }

    function get_USDC_CBETH_MultiPathCalldata(
        address receiver //
    ) internal view returns (bytes memory data) {
        (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        ) = getPath_USDC_CBETH();

        return
            multiPath(
                assets,
                fees,
                dexIds,
                receiver //
            );
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

    function test_light_swap_v3_splits_only() external {
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
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }

    function test_light_swap_v3_splits_with_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        bytes memory swap = v3poolpSwapWithRoute(
            fee,
            fee2,
            uint8(0),
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }

    function test_light_swap_v3_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = abi.encodePacked(
            abi.encodePacked( //
                uint8(ComposerCommands.SWAPS),
                uint128(amount), //
                tokenIn
            ),
            get_USDC_CBETH_MultiPathCalldata(user)
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3 based route
    function v3poolUltiSwapWithRouteV2(
        uint16 fee,
        uint16 fee2,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address assetIn = USDC;
        address assetOut = WETH;
        address v2pool = IF(UNI_V2_FACTORY).getPair(assetOut, KEYCAT);
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            assetIn,
            uint8(1), // swaps max index
            uint8(0) // splits
        );

        data = abi.encodePacked(
            data,
            uint8(0), // 0 multihops
            uint8(2), // splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );

        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            v2pool,
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); //
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            assetOut,
            v2pool,
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); //

        data = abi.encodePacked(
            data,
            get_USDC_WETH_MultiPathCalldata(v2pool) //
        ); //

        data = abi.encodePacked(
            data,
            uint16(0), // atomic
            KEYCAT,
            receiver,
            uint8(100), // uno v2
            // v2 pool data
            v2pool,
            uint16(9970),
            uint16(2) // cll length
        ); //
    }

    // swap 33% uni V3, 33% iZi, 33% other uni V3 based route
    function v3poolUltiSwapWithRoute(
        uint16 fee,
        uint16 fee2,
        uint8 dexId,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address assetIn = USDC;
        address assetOut = WETH;
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        // head
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            assetIn,
            uint8(1), // 2 hops
            uint8(0) // no splits
        );

        data = abi.encodePacked(
            data,
            uint8(0), // 0 hops
            uint8(2), // 3 splits
            (type(uint16).max / 3), // split (1/3)
            (type(uint16).max / 3) // split (2/3)
        );

        data = abi.encodePacked(
            data,
            uint16(0), // atomic swap
            assetOut,
            address(oneDV2),
            dexId,
            // v3 pool data
            pool,
            fee,
            uint16(0) // cll length
        ); //
        pool = IF(IZI_FACTORY).pool(assetIn, assetOut, fee2);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic swap
            assetOut,
            address(oneDV2),
            uint8(49),
            // v3 pool data
            pool,
            fee2,
            uint16(0) // cll length
        ); //

        data = abi.encodePacked(
            data,
            get_USDC_WETH_MultiPathCalldata(address(oneDV2)) //
        ); //

        pool = IF(UNI_FACTORY).getPool(assetOut, cbETH, 500);
        data = abi.encodePacked(
            data,
            uint16(0), // atomic swap
            cbETH,
            receiver,
            uint8(0),
            // v3 pool data
            pool,
            uint16(500),
            uint16(1) // cll length
        ); //
    }

    function test_light_swap_v3_route_splits_with_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = cbETH;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        // USDC ----------> WETH
        // USDC ----------> WETH ---> cbETH
        // USDC -> cbBTC -> WETH
        bytes memory swap = v3poolUltiSwapWithRoute(
            fee,
            fee2,
            uint8(0),
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }

    function test_light_swap_v3_route_splits_with_v2_route() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = KEYCAT;
        uint16 fee = 500;
        uint16 fee2 = 3000;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        // USDC ----------> WETH
        // USDC ----------> WETH ---> KEYCAT
        // USDC -> cbBTC -> WETH
        bytes memory swap = v3poolUltiSwapWithRouteV2(
            fee,
            fee2,
            uint8(0),
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
    }
}
