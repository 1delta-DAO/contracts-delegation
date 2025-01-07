// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

contract DodoTestTaiko is DeltaSetup {
    address internal constant BTC_DODO_POOL = 0xFD5693019a3299Ed402C9A2DAeA9FF82fC7f22EE;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 737350, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();
    }

    function test_taiko_dodo_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensTaiko.stBTC;
        address assetOut = TokensTaiko.enzoBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 0.01e18;

        uint256 quoted = testQuoter.quoteExactInput(
            getQuoteSpotExactInSingleDodoV2(assetIn, assetOut, 1),
            amountIn //
        );
        console.log("quoted", quoted);
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
        assertApproxEqAbs(999501, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_taiko_dodo_spot_exact_in_sell_quote() external {
        address user = testUser;

        vm.assume(user != address(0));
        address assetIn = TokensTaiko.enzoBTC;
        address assetOut = TokensTaiko.stBTC;

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
        assertApproxEqAbs(999499979601850, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function getSpotExactInSingleDodoV2(address tokenIn, address tokenOut, uint8 sellQuote) internal pure returns (bytes memory data) {
        uint8 poolId = DexMappingsTaiko.DODO;
        return abi.encodePacked(tokenIn, uint8(0), poolId, BTC_DODO_POOL, sellQuote, tokenOut);
    }

    function getQuoteSpotExactInSingleDodoV2(address tokenIn, address tokenOut, uint8 sellQuote) internal pure returns (bytes memory data) {
        uint8 poolId = DexMappingsTaiko.DODO;
        return abi.encodePacked(tokenIn, poolId, BTC_DODO_POOL, sellQuote, tokenOut);
    }
}
