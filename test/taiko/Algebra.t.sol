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
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 745292, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();

        testQuoter = new PoolGetter();
        quoter = new QuoterTaiko();
    }

    function test_algebra_taiko() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensTaiko.USDC;
        address assetOut = TokensTaiko.WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e6;

        uint256 quote = quoter.quoteExactInput(getQuoterExactInSingleSgUSDC(assetIn, assetOut), amountIn);

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
        assertApproxEqAbs(5735107188434603, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /**
     * UNISWAP FORK PATH BUILDERS
     */
    function getSpotExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 0;
        uint8 poolId = DexMappingsTaiko.SWAPSICLE;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getQuoterExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 0;
        uint8 poolId = DexMappingsTaiko.SWAPSICLE;
        address pool = testQuoter.v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }
}
