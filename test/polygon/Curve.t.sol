// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract CurveTestPolygon is DeltaSetup {
    uint8 APPROVE_FLAG = 1;

    function test_polygon_curve_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            CURVE,
            1,
            APPROVE_FLAG,
            getCurveIndexes(assetIn, assetOut) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            SUSHI_V3,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataSwapFirst.length),
            dataSwapFirst,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin, false, dataFusion.length),
            dataFusion //
        );

        uint256 bal = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;

        assertApproxEqAbs(bal, 2000284652, 0);
    }

    function test_polygon_curve_ng_single_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e18;
        uint256 amountMin = 1900.0e6;

        address assetIn = crvUSD;
        address assetOut = USDCn;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            CURVE_NG,
            0,
            APPROVE_FLAG,
            getCurveNGIndexes(assetIn) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataSwapFirst.length),
            dataSwapFirst
        );

        uint256 bal = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;

        assertApproxEqAbs(bal, 1995174084, 0);
    }

    function test_polygon_curve_ng_exact_out() external {
        address user = testUser;
        uint gas;
        uint256 amount = 20000.0e6;
        uint256 amountMax = 21000.0e18;

        address assetIn = crvUSD;
        address assetOut = USDCn;
        deal(assetIn, user, amountMax);

        bytes memory dataCurveNg = getSpotExactOutSingleGenCurveNG(
            assetIn,
            assetOut,
            CURVE_NG,
            0, //
            getCurveNGIndexes(assetIn)
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, amountMax, false, dataCurveNg.length),
            dataCurveNg
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amountMax * 2);

        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        bal = IERC20All(assetOut).balanceOf(user) - bal;
        console.log("bal", bal);
    }

    function test_polygon_curve_ng_exact_out_inverse() external {
        address user = testUser;
        uint gas;
        uint256 amount = 2000.0e18;
        uint256 amountMax = 2100.0e6;

        address assetIn = USDCn;
        address assetOut = crvUSD;
        deal(assetIn, user, amountMax);

        bytes memory dataCurveNg = getSpotExactOutSingleGenCurveNG(
            assetIn,
            assetOut,
            CURVE_NG,
            0, //
            getCurveNGIndexes(assetIn)
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, amountMax, false, dataCurveNg.length),
            dataCurveNg
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amountMax * 2);

        uint256 bal = IERC20All(assetOut).balanceOf(user);
        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        bal = IERC20All(assetOut).balanceOf(user) - bal;
        console.log("bal", bal);
    }

    function test_polygon_curve_metapool_factory_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.0000001e8;

        address assetIn = USDC;
        address assetOut = CRV;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getCurveMetaFactoryIndexes(assetIn, assetOut);
        dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            CURVE_META,
            0,
            APPROVE_FLAG,
            dataSwapFirst //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataSwapFirst.length),
            dataSwapFirst
        );

        uint256 bal = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        // expect 6.65k CRV for 2k USDC
        assertApproxEqAbs(bal, 6651.067541215912827155e18, 0);
    }

    function test_polygon_curve_metapool_zap_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.0000001e8;

        address assetIn = USDC;
        address assetOut = WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getCurveMetaZapStandaloneIndexes(assetIn, assetOut);
        dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            CURVE,
            2,
            APPROVE_FLAG,
            dataSwapFirst //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataSwapFirst.length),
            dataSwapFirst
        );

        uint256 bal = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        bal = IERC20All(assetOut).balanceOf(user) - bal;
        // expect to receive 0.03268741 WBTC
        assertApproxEqAbs(bal, 3268741, 0);
    }

    function crvAaveIndexes(address asset) internal pure returns (uint8) {
        if (asset == DAI) return 0;
        if (asset == USDC) return 1;
        if (asset == USDT) return 2;
        revert("crvAaveIndexes -> index");
    }

    function crvAaveFactoryIndexes(address asset) internal pure returns (uint8) {
        if (asset == USDC) return 2;
        revert("crvAaveFactoryIndexes -> index");
    }

    function crvTriMetaIndexes(address asset) internal pure returns (uint8) {
        if (asset == WBTC) return 3;
        if (asset == WETH) return 2;
        revert("crvTriMetaIndexes -> index");
    }

    function crvCrvIndex(address asset) internal pure returns (uint8) {
        if (asset == CRV) return 0;
        revert("crvCrvIndex -> index");
    }

    function getCurveIndexes(address assetIn, address assetOut) internal pure returns (bytes memory data) {
        return abi.encodePacked(CRV_3_USD_AAVE_POOL, crvAaveIndexes(assetIn), crvAaveIndexes(assetOut));
    }

    function getCurveMetaFactoryIndexes(address assetIn, address assetOut) internal pure returns (bytes memory data) {
        return abi.encodePacked(CRV_FACTORY_ZAP, CRV_CRV_FACTORY_POOL, crvAaveFactoryIndexes(assetIn), crvCrvIndex(assetOut));
    }

    function getCurveMetaZapStandaloneIndexes(address assetIn, address assetOut) internal pure returns (bytes memory data) {
        return abi.encodePacked(CRV_TRICRYPTO_ZAP, crvAaveIndexes(assetIn), crvTriMetaIndexes(assetOut));
    }

    function getCurveNGIndexes(address assetIn) internal pure returns (bytes memory data) {
        (uint8 indexIn, uint8 indexOut) = assetIn == crvUSD ? (0, 1) : (1, 0);
        return abi.encodePacked(CRV_NG_USDN_CRVUSD, indexIn, indexOut);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleGenCurve(
        address tokenIn, //
        address tokenOut,
        uint8 pId,
        uint8 selectorId,
        uint8 preActionFlag,
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, pId, data, selectorId, preActionFlag, tokenOut);
    }

    function getSpotExactInSingleGenCurveNG(
        address tokenIn, //
        address tokenOut,
        uint8 pId,
        uint8 selectorId,
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, pId, data, selectorId, tokenOut);
    }

    function getSpotExactOutSingleGenCurveNG(
        address tokenIn, //
        address tokenOut,
        uint8 pId,
        uint8 selectorId,
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, pId, data, selectorId, tokenIn, uint8(0), uint8(99));
    }

    function getCurveMeta(
        address tokenIn, //
        address tokenOut,
        uint8 pId,
        uint8 preActionFlag,
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, pId, data, uint8(1), preActionFlag, tokenOut);
    }
}

// Ran 11 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_polygon_composer_borrow() (gas: 917038)
// Logs:
//   gas 378730
//   gas 432645

// [PASS] test_polygon_composer_depo() (gas: 371016)
// Logs:
//   gas 248957

// [PASS] test_polygon_composer_multi_route_exact_in() (gas: 377134)
// Logs:
//   gas 192095

// [PASS] test_polygon_composer_multi_route_exact_in_native() (gas: 368206)
// Logs:
//   gas 374361

// [PASS] test_polygon_composer_multi_route_exact_in_native_out() (gas: 633199)
// Logs:
//   gas-exactIn-native-out-2 split 547586

// [PASS] test_polygon_composer_multi_route_exact_in_self() (gas: 399348)
// Logs:
//   gas 219240

// [PASS] test_polygon_composer_multi_route_exact_out() (gas: 390674)
// Logs:
//   gas 190957

// [PASS] test_polygon_composer_multi_route_exact_out_native_in() (gas: 408213)
// Logs:
//   gas-exactOut-native-in-2 split 385726

// [PASS] test_polygon_composer_multi_route_exact_out_native_out() (gas: 558685)
// Logs:
//   gas-exactOut-native-out-2 split 413439

// [PASS] test_polygon_composer_repay() (gas: 985744)
// Logs:
//   gas 378730
//   gas 432646
//   gas 102301

// [PASS] test_polygon_composer_withdraw() (gas: 702003)
// Logs:
//   gas 378730
//   gas 253948

// Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 319.97ms (40.41ms CPU time)
