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
    uint8 internal constant DTX_DEX_ID = 1;
    uint8 internal constant UNISWAP_V3_POOL_ID = 0;

    TestQuoterTaiko testQuoter1;
    address internal router = 0x38be8Bc0cDfF59eF9B9Feb0d949B2052359e97d9;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 389172, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();

        testQuoter1 = new TestQuoterTaiko();
    }

    function test_dtx_usdc_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = USDC;
        address assetOut = WETH;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 20.0e6;

        console.log("DTX factory", IHasFactory(router).factory());

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
        assertApproxEqAbs(8585963874116459, balanceOut, 1);
        assertApproxEqAbs(quote, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** UNISWAP FORK PATH BUILDERS */

    function getSpotExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 3000;
        uint8 poolId = DTX_DEX_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getQuoterExactInSingleSgUSDC(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = 3000;
        uint8 poolId = DTX_DEX_ID;
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenIn, poolId, pool, fee, tokenOut);
    }
}