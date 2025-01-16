// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

contract DodoTestTaiko is DeltaSetup {
    // base: SolvBtc
    // quote: Solv BTC BBN
    address internal constant BTC_DODO_POOL = 0xb56F2a15c3540C5D5F4ddB58650fDC7972027A51;
    address internal constant BTC_PANKO_POOL = 0xC55E123cf0a6E7e9221174F0A7501E85FebaA723;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 768356, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});

        intitializeFullDelta();
    }

    function test_taiko_dodo_flash_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensTaiko.SOLV_BTC_BBN;
        address assetOut = TokensTaiko.SOLV_BTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 0.40e18;

        console.log("quote");
        uint256 quoted = quoter.quoteExactInput(
            getQuoteSpotExactInSingleDodoV2(assetIn, assetOut),
            amountIn //
        );
        console.log("quoted", quoted);
        console.log("quoted profit", quoted - amountIn);
        bytes memory swapPath = getFlashExactInDodoSingle(assetIn, assetOut);
        uint256 minimumOut = 0.001e8;

        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            data,
            sweep(
                assetIn,
                user,
                0, //
                ComposerUtils.SweepType.VALIDATE
            )
        );

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        console.logBytes(data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceIn = IERC20All(assetIn).balanceOf(user) - balanceIn;
        console.log("added in", balanceIn);
        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(balanceIn, 1427143279815404, 0);
    }

    function getQuoteSpotExactInSingleDodoV2(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        data = abi.encodePacked(tokenIn, DexMappingsTaiko.DODO, BTC_DODO_POOL, uint8(1), tokenOut);

        return
            abi.encodePacked(
                data,
                DexMappingsTaiko.PANKO_STABLE_DEX_ID,
                BTC_PANKO_POOL,
                getPankoStableIndex(TokensTaiko.SOLV_BTC),
                getPankoStableIndex(TokensTaiko.SOLV_BTC_BBN),
                uint8(3),
                tokenIn
            );
    }

    function getFlashExactInDodoSingle(address tokenIn, address tokenOut) internal pure returns (bytes memory data) {
        uint8 poolId = DexMappingsTaiko.DODO;
        data = abi.encodePacked(tokenIn, uint8(0), poolId, BTC_DODO_POOL, uint8(1), tokenOut);

        return
            abi.encodePacked(
                data,
                uint8(0),
                DexMappingsTaiko.PANKO_STABLE_DEX_ID,
                BTC_PANKO_POOL,
                getPankoStableIndex(TokensTaiko.SOLV_BTC),
                getPankoStableIndex(TokensTaiko.SOLV_BTC_BBN),
                uint8(3),
                tokenIn
            );
    }

    function getPankoStableIndex(address token) internal pure returns (uint8) {
        if (token == TokensTaiko.SOLV_BTC) return 0;
        else if (token == TokensTaiko.SOLV_BTC_BBN) return 1;
        else revert();
    }
}
