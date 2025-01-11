// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract CurveTestArbitrum is DeltaSetup {
    address constant CURVE_USDCE_USDT = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    address constant TBTC = 0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40;
    address constant CURVE_TBTC_BTC_NG = 0x186cF879186986A20aADFb7eAD50e3C20cb26CeC;

    function test_arbitrum_curve_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 1900.0e6;

        address assetIn = TokensArbitrum.USDCE;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsArbitrum.CURVE,
            0,
            getCurveIndexes(assetIn, assetOut) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            DexMappingsArbitrum.SUSHI_V3,
            DEX_FEE_STABLES //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin / 2, false, dataSwapFirst.length),
            dataSwapFirst,
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount / 2, amountMin / 2, false, dataFusion.length),
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

        assertApproxEqAbs(bal, 2004096242, 0);
    }

    function test_arbitrum_curve_ng_single_route_exact_in() external {
        address user = testUser;
        uint256 amount = 1.0e18;
        uint256 amountMin = 0.98e8;

        address assetIn = TBTC;
        address assetOut = TokensArbitrum.WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataSwapFirst = getSpotExactInSingleGenCurve(
            assetIn,
            assetOut,
            DexMappingsArbitrum.CURVE_NG,
            0,
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

        assertApproxEqAbs(bal, 99883886, 0);
    }

    function crv2PoolIndexes(address asset) internal pure returns (uint8) {
        if (asset == TokensArbitrum.USDCE) return 0;
        if (asset == TokensArbitrum.USDT) return 1;
        revert("crv2PoolIndexes -> index");
    }

    function crvCrvIndex(address asset) internal pure returns (uint8) {
        if (asset == TokensArbitrum.WETH) return 0;
        revert("crvCrvIndex -> index");
    }

    function getCurveIndexes(address assetIn, address assetOut) internal pure returns (bytes memory data) {
        return abi.encodePacked(CURVE_USDCE_USDT, crv2PoolIndexes(assetIn), crv2PoolIndexes(assetOut));
    }

    function getCurveNGIndexes(address assetIn) internal pure returns (bytes memory data) {
        (uint8 indexIn, uint8 indexOut) = assetIn != TBTC ? (0, 1) : (1, 0);
        return abi.encodePacked(CURVE_TBTC_BTC_NG, indexIn, indexOut);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
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

}
