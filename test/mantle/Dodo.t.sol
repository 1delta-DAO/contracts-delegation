// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests DODO V2 style DEXs exact in swaps
 */
contract DOdoTest is DeltaSetup {
    address someOtherUser = 0x813fBB2915B96DFbE00D88dd3D842b6e3e91FB38;

    address internal FBTC_WBTC_POOL = 0xD39DFbfBA9E7eccd813918FfbDa10B783EA3b3C6;
    address internal FBTC = 0xC96dE26018A54D51c097160568752c4E3BD6C364;
    uint8 DODO = 153;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 66900822, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    function test_mantle_dodo_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WBTC;
        address assetOut = FBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 0.01e8;

        bytes memory swapPath = getSpotExactInSingleDodoV2(assetIn, assetOut, 1);
        uint256 minimumOut = 0.001e8;

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(999400, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_dodo_spot_exact_in_multi() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WBTC;
        address assetOut = METH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 0.01e8;

        bytes memory swapPath = getSpotExactInSingleDodoV2Multi(assetIn, assetOut, 1);
        uint256 minimumOut = 0.001e8;

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(189065837083794161, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_dodo_spot_exact_in_sell_quote() external {
        address user = testUser;

        // the pool has little WBTC in it, we fund it here
        fundSwap(someOtherUser);

        vm.assume(user != address(0));
        address assetIn = FBTC;
        address assetOut = WBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 0.001e8;

        bytes memory swapPath = getSpotExactInSingleDodoV2(assetIn, assetOut, 0);
        uint256 minimumOut = 0.0009e8;

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(99940, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** KTX PATH BUILDERS */

    function getSpotExactInSingleDodoV2(address tokenIn, address tokenOut, uint8 sellQuote) internal view returns (bytes memory data) {
        uint8 poolId = DODO;
        return abi.encodePacked(tokenIn, uint8(0), poolId, FBTC_WBTC_POOL, sellQuote, tokenOut);
    }

    function getSpotExactInSingleDodoV2Multi(address tokenIn, address tokenOut, uint8 sellQuote) internal view returns (bytes memory data) {
        uint8 poolId = DODO;
        uint16 fee = 2500;
        address agniPool = testQuoter._v3TypePool(FBTC, tokenOut, fee, AGNI);
        return
            abi.encodePacked(
                tokenIn,
                uint8(0),
                poolId,
                FBTC_WBTC_POOL,
                sellQuote,
                FBTC,
                uint8(0),
                AGNI,
                agniPool,
                fee, //
                tokenOut,
                uint16(0)
            );
    }

    function fundSwap(address user) internal {
        address assetIn = WBTC;
        address assetOut = FBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 1.0e8;

        bytes memory swapPath = getSpotExactInSingleDodoV2(assetIn, assetOut, 1);
        uint256 minimumOut = 0.001e8;

        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountIn, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
    }
}
