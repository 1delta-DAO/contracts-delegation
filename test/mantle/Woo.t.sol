// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests WooFi exact in swaps
 */
contract WooFiTest is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 64033576, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function test_mantle_woo_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.USDC;
        address assetOut = TokensMantle.WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 1.0e6;

        uint256 quoted = testQuoter._quoteWooFiExactIn(assetIn, assetOut, amountIn);

        bytes memory swapPath = getSpotExactInSingleWOO_FI(assetIn, assetOut);
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

        // swap 1 TokensMantle.USDC, receive approx 0.00032111343 TokensMantle.WETH, but in 18 decs
        assertApproxEqAbs(321113436165101, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** WOO_FI PATH BUILDERS */

    function getSpotExactInSingleWOO_FI(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.WOO_FI;
        return abi.encodePacked(tokenIn, uint8(0), poolId, WOO_POOL, tokenOut);
    }
}
