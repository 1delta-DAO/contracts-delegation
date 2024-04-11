// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";
import "../../contracts/1delta/quoter/test/TestQuoterMantle.sol";

/**
 * Tests Merchant Moe's LB in all configs
 * Exact out ath the beginning, end
 * Exact in at the begginging, end
 * Payment variations
 *  - continue swap
 *  - pay from user balance
 *  - pay with credit line
 *  - pay through withdrawal
 */
contract GeneralMoeLBTest is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    TestQuoterMantle testQuoter;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
        testQuoter = new TestQuoterMantle();
    }

    function test_mantle_ktx_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = WETH;
        address assetOut = WBTC;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter._quoteKTXExactIn(assetIn, assetOut, amountIn);

        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, assetIn, amountIn);

        bytes memory swapPath = getSpotExactInSingleKTX(assetIn, assetOut);
        uint256 minimumOut = 0.03e8;
        calls[1] = abi.encodeWithSelector(
            IFlashAggregator.swapExactInSpot.selector, // 3 args
            amountIn,
            minimumOut,
            swapPath
        );

        calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        brokerProxy.multicall(calls);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(5109227, balanceOut, 1);
        assertApproxEqAbs(quoted, balanceOut, 0);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }


    /** MOE LB PATH BUILDERS */

    function getOpenExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getSpotExactInSingleKTX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = 0;
        uint8 poolId = KTX;
        return abi.encodePacked(tokenIn, fee, poolId, uint8(0), tokenOut, uint8(99));
    }

    function getSpotExactOutSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(tokenOut, fee, poolId, uint8(1), tokenIn, uint8(99));
    }

    function getSpotExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = BIN_STEP_LOWEST;
        uint8 poolId = MERCHANT_MOE_LB;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, uint8(1), USDT);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, uint8(1), tokenIn, uint8(99));
    }

    function getSpotExactOutMultiLBEnd(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, uint8(1), USDT);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, uint8(1), tokenIn, uint8(99));
    }

    function getSpotExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = AGNI;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getOpenExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    function getCloseExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    function getCloseExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDe);
        fee = BIN_STEP_LOWEST;
        poolId = MERCHANT_MOE_LB;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    /** DEPO AND BORROW HELPER */

    function _deposit(address user, address asset, uint256 amount) internal {
        deal(asset, user, amount);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.transferERC20In.selector, asset, amount);
        calls[1] = abi.encodeWithSelector(ILending.deposit.selector, asset, user);
        vm.prank(user);
        brokerProxy.multicall(calls);
    }

    function _borrow(address user, address asset, uint256 amount) internal {
        address debtAsset = debtTokens[asset][DEFAULT_LENDER];
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amount);
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(ILending.borrow.selector, asset, amount, DEFAULT_IR_MODE);
        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, asset, user);
        vm.prank(user);
        brokerProxy.multicall(calls);
    }
}
