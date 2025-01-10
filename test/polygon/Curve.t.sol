// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract CurveTestPolygon is DeltaSetup {
    uint8 APPROVE_FLAG = 1;

    uint8 internal constant EXCHANGE_META_RECEIVER_SELECTOR = 0;
    uint8 internal constant EXCHANGE_META_SELECTOR = 1;

    uint8 internal constant EXCHANGE_INT_RECEIVER_SELECTOR = 0;
    uint8 internal constant EXCHANGE_UNDERLYING_INT_SELECTOR = 5;
    uint8 internal constant EXCHANGE_UNDERLYING_RECEIVER_SELECTOR = 6;
    uint8 internal constant EXCHANGE_UNDERLYING_SELECTOR = 7;
    uint8 internal constant EXCHANGE_RECEIVER_SELECTOR = 3;

    uint8 internal constant NG_EXCHANGE_INT_SELECTOR = 1;
    uint8 internal constant NG_EXCHANGE_RECEIVER_INT_SELECTOR = 0;

    function test_polygon_curve_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE,
            EXCHANGE_UNDERLYING_INT_SELECTOR,
            getCurveIndexes(assetIn, assetOut) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsPolygon.SUSHI_V3,
            DEX_FEE_STABLES //
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

        address assetIn = TokensPolygon.crvUSD;
        address assetOut = TokensPolygon.USDCn;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE_NG,
            EXCHANGE_INT_RECEIVER_SELECTOR,
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

        address assetIn = TokensPolygon.crvUSD;
        address assetOut = TokensPolygon.USDCn;
        deal(assetIn, user, amountMax);

        bytes memory dataCurveNg = getSpotExactOutSingleGenCurveNG(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE_NG,
            NG_EXCHANGE_RECEIVER_INT_SELECTOR, //
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

        address assetIn = TokensPolygon.USDCn;
        address assetOut = TokensPolygon.crvUSD;
        deal(assetIn, user, amountMax);

        bytes memory dataCurveNg = getSpotExactOutSingleGenCurveNG(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE_NG,
            NG_EXCHANGE_RECEIVER_INT_SELECTOR, //
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

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.CRV;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getCurveMetaFactoryIndexes(assetIn, assetOut);
        dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE_META,
            EXCHANGE_META_SELECTOR,
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
        // expect 6.65k CRV for 2k TokensPolygon.USDC
        assertApproxEqAbs(bal, 6651.067541215912827155e18, 0);
    }

    function test_polygon_curve_metapool_zap_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.0000001e8;

        address assetIn = TokensPolygon.USDC;
        address assetOut = TokensPolygon.WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getCurveMetaZapStandaloneIndexes(assetIn, assetOut);
        dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsPolygon.CURVE,
            EXCHANGE_UNDERLYING_RECEIVER_SELECTOR,
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
        // expect to receive 0.03268741 TokensPolygon.WBTC
        assertApproxEqAbs(bal, 3268741, 0);
    }

    function crvAaveIndexes(address asset) internal pure returns (uint8) {
        if (asset == TokensPolygon.DAI) return 0;
        if (asset == TokensPolygon.USDC) return 1;
        if (asset == TokensPolygon.USDT) return 2;
        revert("crvAaveIndexes -> index");
    }

    function crvAaveFactoryIndexes(address asset) internal pure returns (uint8) {
        if (asset == TokensPolygon.USDC) return 2;
        revert("crvAaveFactoryIndexes -> index");
    }

    function crvTriMetaIndexes(address asset) internal pure returns (uint8) {
        if (asset == TokensPolygon.WBTC) return 3;
        if (asset == TokensPolygon.WETH) return 2;
        revert("crvTriMetaIndexes -> index");
    }

    function crvCrvIndex(address asset) internal pure returns (uint8) {
        if (asset == TokensPolygon.CRV) return 0;
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
        (uint8 indexIn, uint8 indexOut) = assetIn == TokensPolygon.crvUSD ? (0, 1) : (1, 0);
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
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, pId, data, selectorId, tokenOut);
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
        bytes memory data
    ) internal pure returns (bytes memory) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, pId, data, uint8(1), tokenOut);
    }
}
