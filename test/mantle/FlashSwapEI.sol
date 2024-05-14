// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterMantle.sol";

/**
 * Tests Curve style DEXs exact in swaps
 */
contract FlashSwapExacInTest is DeltaSetup {
    TestQuoterMantle testQuoter;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
        testQuoter = new TestQuoterMantle();
    }

    function test_mantle_stratum_arb_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = WETH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInSingleStratumMETHQuoter(WETH), amountIn);

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactInSingleStratumMETH(asset);
        uint256 minimumOut = amountIn;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactIn.selector, // 3 args
            amountIn,
            minimumOut,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        // This amount should be positive if there is extractable arbitrage
        assetBalance = IERC20All(asset).balanceOf(user) - assetBalance;

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(quoted - amountIn, assetBalance, 0);
    }

    function test_mantle_stratum_arb_exact_in_v2() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = WETH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2(WETH), amountIn);

        bytes[] memory calls = new bytes[](3);

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2(asset);

        // since we use MerchantMode, we expect a loss inn execution, we have to contribute this amount
        uint256 residual = quoted >= amountIn ? 0 : amountIn - quoted;
        deal(asset, user, residual);

        uint256 minimumOut = quoted;
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, residual);
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.flashSwapExactIn.selector, // 3 args
            amountIn,
            minimumOut,
            swapPath
        );

        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        // This amount should be positive if there is a loss
        assetBalance = assetBalance - IERC20All(asset).balanceOf(user);

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(quoted, amountIn - assetBalance, 0);
    }

    /** PATH BUILDERS */

    function getTokenIdEth(address t) internal view returns (uint8) {
        if (t == METH) return 1;
        else return 0;
    }

    function getSpotExactInAgni(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = AGNI;
        return abi.encodePacked(tokenIn, DEX_FEE_STABLES, poolId, uint8(0), tokenOut);
    }

    function getSpotExactInSingleStratumMETH(address token) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return
            abi.encodePacked(
                getSpotExactInAgni(token, METH),
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token), uint8(0)),
                poolId,
                uint8(0),
                token,
                uint8(99)
            );
    }

    function getSpotExactInAgniQuoter(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = AGNI;
        return abi.encodePacked(tokenIn, DEX_FEE_STABLES, poolId, tokenOut);
    }

    function getSpotExactInMoeQuoter(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        return abi.encodePacked(tokenIn, DEX_FEE_NONE, poolId, tokenOut);
    }

    function getSpotExactInSingleStratumMETHQuoter(address token) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return
            abi.encodePacked(
                getSpotExactInAgniQuoter(token, METH),
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token), uint8(0)),
                poolId,
                token
            );
    }

    function getSpotExactInDoubleStratumMETHV2(address token) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return
            abi.encodePacked(
                getSpotExactInMoe(token, METH),
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token), uint8(0)),
                poolId,
                uint8(0),
                token,
                uint8(99)
            );
    }

    function getSpotExactInMoe(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        return abi.encodePacked(tokenIn, DEX_FEE_NONE, poolId, uint8(0), tokenOut);
    }

    function getSpotExactInDoubleStratumMETHQuoterWithV2(address token) internal view returns (bytes memory data) {
        uint8 poolId = STRATUM_CURVE;
        return
            abi.encodePacked(
                getSpotExactInMoeQuoter(token, METH),
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token), uint8(0)),
                poolId,
                token
            );
    }
}
