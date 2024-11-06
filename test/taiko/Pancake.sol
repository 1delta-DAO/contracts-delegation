// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

interface IHasFactory {
    function factory() external view returns (address);
}

/**
 * Tests Uni V3 style DEX
 */
contract UniV3TypeTest is DeltaSetup {
    uint8 internal constant PANKO_DEX_ID = 3;
    uint8 internal constant PANKO_STABLE_DEX_ID = 60;
    address internal constant PANKO_STABLE_USDT_USDC_POOl = 0x3136Ef69a9E55d7769cFED39700799Bb328d9B46;

    TestQuoterTaiko testQuoter1;
    address internal router = 0x38be8Bc0cDfF59eF9B9Feb0d949B2052359e97d9;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 536078, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();

        testQuoter1 = new TestQuoterTaiko();
    }

    function test_panko_v3_usdc_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDC;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e6;

        uint256 quote = testQuoter1.quoteExactInput(getQuoterExactInSingleSgUSDC(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSingleSgUSDC(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(7472911254128993, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_panko_stable_usdc_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDC;
        address assetOut = USDT;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 200.0e6;

        uint256 quote = testQuoter1.quoteExactInput(getQuoterStableExactInSingleSgUSDC(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotStableExactInSingleSgUSDC(assetIn, assetOut);
        uint256 minimumOut = 198.03e6;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(200012285, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_panko_usdc_spot_exact_in_multi() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDT;
        address assetMid = USDC;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 400.0e6;

        uint256 quote = testQuoter1.quoteExactInput(getQuoterExactInMultiSgUSDC(assetIn, assetMid, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInMultiSgUSDC(assetIn, assetMid, assetOut);
        uint256 minimumOut = 0.03e8;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 400, receive approx 10, but in 18 decs
        assertApproxEqAbs(149125344889034608, balanceOut, 373976482);
        assertApproxEqAbs(quote, balanceOut, 373976482);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** UNISWAP FORK PATH BUILDERS */

    function getSpotExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 2500;
        uint8 poolId = PANKO_DEX_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    /** V3 STYLE */

    function getQuoterExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 2500;
        uint8 poolId = PANKO_DEX_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }

    function getSpotStableExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = PANKO_STABLE_DEX_ID;
        uint8 indexIn = uint8(getPankoStableIndex(tokenIn));
        uint8 indexOut = uint8(getPankoStableIndex(tokenOut));
        address pool = PANKO_STABLE_USDT_USDC_POOl;
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, indexIn, indexOut, uint8(0), tokenOut);
    }

    /** STABLE STYLE */

    function getQuoterStableExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = PANKO_STABLE_DEX_ID;
        uint8 indexIn = uint8(getPankoStableIndex(tokenIn));
        uint8 indexOut = uint8(getPankoStableIndex(tokenOut));
        address pool = PANKO_STABLE_USDT_USDC_POOl;
        return abi.encodePacked(tokenIn, poolId, pool, indexIn, indexOut, uint8(0), tokenOut);
    }

    function getPankoStableIndex(address token) internal view returns (uint) {
        if (token == USDC) return 0;
        else if (token == USDT) return 1;
        else revert();
    }

    /** MULTI */

    function getSpotExactInMultiSgUSDC(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = PANKO_STABLE_DEX_ID;
        uint8 indexIn = uint8(getPankoStableIndex(tokenIn));
        uint8 indexOut = uint8(getPankoStableIndex(mid));
        address pool = PANKO_STABLE_USDT_USDC_POOl;
        data = abi.encodePacked(tokenIn, uint8(0), poolId, pool, indexIn, indexOut, uint8(0), mid);
        uint16 fee = 2500;
        poolId = PANKO_DEX_ID;
        pool = testQuoter._v3TypePool(mid, tokenOut, fee, poolId);
        return abi.encodePacked(data, abi.encodePacked(uint8(0), poolId, pool, fee, tokenOut));
    }

    function getQuoterExactInMultiSgUSDC(address tokenIn, address mid, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = PANKO_STABLE_DEX_ID;
        uint8 indexIn = uint8(getPankoStableIndex(tokenIn));
        uint8 indexOut = uint8(getPankoStableIndex(mid));
        address pool = PANKO_STABLE_USDT_USDC_POOl;
        data = abi.encodePacked(tokenIn, poolId, pool, indexIn, indexOut, uint8(0), mid);
        uint16 fee = 2500;
        poolId = PANKO_DEX_ID;
        pool = testQuoter._v3TypePool(mid, tokenOut, fee, poolId);
        return abi.encodePacked(data, abi.encodePacked(poolId, pool, fee, tokenOut));
    }
}
