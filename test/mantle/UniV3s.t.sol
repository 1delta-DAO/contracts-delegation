// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * Tests Uni V3 style DEX
 */
contract GeneralMoeLBTest is DeltaSetup {

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    function test_mantle_puff_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = METH;
        address assetOut = PUFF;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e18;

        bytes[] memory calls = new bytes[](1);

        uint256 quote = testQuoter.quoteExactInput(getSpotQuoteExactInSinglePuff(assetIn, assetOut), amountIn);

        bytes memory swapPath = getSpotExactInSinglePuff(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            user,
            swapPath
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(265342914918784533562351, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** KTX PATH BUILDERS */

    function getSpotExactInSinglePuff(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        uint16 fee = 3000;
        uint8 poolId = 5;
        return abi.encodePacked(tokenIn, uint8(10), poolId , fee, tokenOut);
    }

    function getSpotQuoteExactInSinglePuff(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        uint24 fee = 3000;
        uint8 poolId = 5;
        return abi.encodePacked(tokenIn, fee, poolId, tokenOut);
    }
}
