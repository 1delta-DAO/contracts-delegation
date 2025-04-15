// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

interface ILBFactory {
    struct LBPairInformation {
        uint16 binStep;
        address LBPair;
        bool createdByOwner;
        bool ignoredForRouting;
    }

    function getLBPairInformation(address tokenX, address tokenY, uint256 binStep) external view returns (LBPairInformation memory);
}

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

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 62267594, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        intitializeFullDelta();
    }

    function test_mantle_lb_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetIn = TokensMantle.USDT;
        address assetOut = TokensMantle.USDe;

        deal(assetIn, user, 1e20);

        uint256 amountIn = 10.0e6;

        bytes memory swapPath = getSpotExactInSingleLB(assetIn, assetOut);
        uint256 minimumOut = 10.0e6;

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
        assertApproxEqAbs(9973011097320898560, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    function test_mantle_lb_spot_exact_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDT;
        address assetIn = TokensMantle.USDe;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e6;

        bytes memory swapPath = getSpotExactOutSingleLB(assetIn, assetOut);
        uint256 maximumIn = 10.0e18;

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(9977001498840374757, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 0);
    }

    function test_mantle_lb_spot_exact_out_multi() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDe;
        address assetIn = TokensMantle.USDC;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e18;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutMultiLB(assetIn, assetOut);
        uint256 maximumIn = 10.5e6;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            user,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(10091372, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 1e12);
    }

    function test_mantle_lb_spot_exact_out_multi_end() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetOut = TokensMantle.USDC;
        address assetIn = TokensMantle.USDe;

        deal(assetIn, user, 1e30);

        uint256 amountOut = 10.0e6;

        bytes[] memory calls = new bytes[](2);

        bytes memory swapPath = getSpotExactOutMultiLBEnd(assetIn, assetOut);
        uint256 maximumIn = 10.5e18;
        calls[0] = abi.encodeWithSelector(
            IFlashAggregator.swapExactOutSpot.selector, // 3 args
            amountOut,
            maximumIn,
            user,
            swapPath
        );

        calls[1] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountOut, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(9973416762201841411, balanceIn, 1);
        assertApproxEqAbs(balanceOut, amountOut, 1e12);
    }

    function test_margin_mantle_lb_open_exact_in_multi() external {
        uint16 lenderId = LenderMappingsMantle.LENDLE_ID;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = TokensMantle.USDT;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = TokensMantle.USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        uint256 amountToDeposit = 10.0e6;

        _deposit(user, asset, amountToDeposit);

        uint256 amountToLeverage = 2.0e6;
        bytes memory swapPath = getOpenExactInMultiLB(borrowAsset, asset);
        uint256 minimumOut = 1.95e6;

        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amountToLeverage);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountToLeverage, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // swap 2.0 for approx 1.98
        assertApproxEqAbs(1983226, balance, 1);
        assertApproxEqAbs(borrowBalance, amountToLeverage, 0);
    }

    function test_margin_mantle_lb_open_exact_out_multi() external {
        uint16 lenderId = LenderMappingsMantle.LENDLE_ID;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = TokensMantle.USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = TokensMantle.USDT;
        address debtAsset = debtTokens[borrowAsset][lenderId];
        uint256 amountToDeposit = 10.0e6;

        _deposit(user, asset, amountToDeposit);

        uint256 amountToReceive = 2.0e6;
        bytes memory swapPath = getOpenExactOutMultiLB(borrowAsset, asset);
        uint256 maximumIn = 2.05e6;

        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, maximumIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = IERC20All(collateralAsset).balanceOf(user) - balance;
        borrowBalance = IERC20All(debtAsset).balanceOf(user) - borrowBalance;

        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(2022639, borrowBalance, 1);
        // deposit 10, recieve 30 makes 40
        assertApproxEqAbs(balance, amountToReceive, 0);
    }

    function test_margin_mantle_lb_close_exact_in_multi() external {
        uint16 lenderId = LenderMappingsMantle.LENDLE_ID;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = TokensMantle.USDC;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = TokensMantle.USDT;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 30.0e6;
            uint256 amountToLeverage = 10.0e6;
            _deposit(user, asset, amountToDeposit);
            _borrow(user, borrowAsset, amountToLeverage);
        }

        bytes memory swapPath = getCloseExactInMultiLB(asset, borrowAsset);
        uint256 amountIn = 1.5e6;
        uint256 minimumOut = 1.48e6; // this one provides a bad swap rate

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountIn);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);
        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amountIn,
            minimumOut,
            false, //
            swapPath
        );
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        assertApproxEqAbs(amountIn, balance, 1);
        // receive approx. 1.5 from 1.5 stable swap
        assertApproxEqAbs(1489871, borrowBalance, 1);
    }

    function test_margin_mantle_lb_close_exact_out_multi() external {
        uint16 lenderId = LenderMappingsMantle.LENDLE_ID;
        address user = testUser;
        vm.assume(user != address(0));
        address asset = TokensMantle.USDT;
        address collateralAsset = collateralTokens[asset][lenderId];

        address borrowAsset = TokensMantle.USDC;
        address debtAsset = debtTokens[borrowAsset][lenderId];

        {
            uint256 amountToDeposit = 30.0e6;
            uint256 amountToLeverage = 10.0e6;
            _deposit(user, asset, amountToDeposit);
            _borrow(user, borrowAsset, amountToLeverage);
        }

        bytes memory swapPath = getCloseExactOutMultiLB(asset, borrowAsset);
        uint256 amountOut = 1.0e6;
        uint256 amountInMaximum = 1.2e6;

        vm.prank(user);
        IERC20All(collateralAsset).approve(brokerProxyAddress, amountInMaximum);

        uint256 borrowBalance = IERC20All(debtAsset).balanceOf(user);
        uint256 balance = IERC20All(collateralAsset).balanceOf(user);

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_OUT,
            amountOut, //
            amountInMaximum,
            false,
            swapPath
        );

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);

        balance = balance - IERC20All(collateralAsset).balanceOf(user);
        borrowBalance = borrowBalance - IERC20All(debtAsset).balanceOf(user);

        // deposit 10, recieve 32.1... makes 42.1...
        assertApproxEqAbs(1007949, balance, 1);
        // deviations through rouding expected, accuracy for 10 decimals
        assertApproxEqAbs(amountOut, borrowBalance, 1);
    }

    /**
     * MOE LB PATH BUILDERS
     */
    function getOpenExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDe, tokenIn, DexMappingsMantle.MERCHANT_MOE);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDe);
        poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.USDe, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, LenderMappingsMantle.LENDLE_ID, endId);
    }

    function getSpotExactInSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = BIN_STEP_LOWEST;
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, tokenIn, fee).LBPair;
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, tokenOut, uint8(99));
    }

    function getSpotExactOutSingleLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, tokenIn, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(tokenOut, uint8(0), poolId, pool, tokenIn);
    }

    function getSpotExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        address pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.USDT, BIN_STEP_LOWEST).LBPair;

        bytes memory firstPart = abi.encodePacked(tokenOut, uint8(0), poolId, pool, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE;
        pool = testQuoter.v2TypePairAddress(TokensMantle.USDT, tokenIn, DexMappingsMantle.MERCHANT_MOE);
        return abi.encodePacked(firstPart, uint8(0), poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenIn);
    }

    function getSpotExactOutMultiLBEnd(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDT, tokenOut, DexMappingsMantle.MERCHANT_MOE);
        bytes memory firstPart = abi.encodePacked(tokenOut, uint8(0), poolId, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenIn, TokensMantle.USDT, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, uint8(0), poolId, pool, tokenIn);
    }

    function getSpotExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(TokensMantle.USDT, tokenIn, poolId, DEX_FEE_LOW);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, poolId, pool, DEX_FEE_LOW, TokensMantle.USDT);
        poolId = DexMappingsMantle.MERCHANT_MOE_LB;
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.USDT, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, midId, poolId, pool, tokenOut, endId);
    }

    function getOpenExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDe, tokenOut, DexMappingsMantle.MERCHANT_MOE);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, DexMappingsMantle.MERCHANT_MOE, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDe);
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenIn, TokensMantle.USDe, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, midId, DexMappingsMantle.MERCHANT_MOE_LB, pool, tokenIn, LenderMappingsMantle.LENDLE_ID, endId);
    }

    function getCloseExactOutMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDe, tokenOut, DexMappingsMantle.MERCHANT_MOE);
        bytes memory firstPart = abi.encodePacked(tokenOut, actionId, DexMappingsMantle.MERCHANT_MOE, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDe);
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenIn, TokensMantle.USDe, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, midId, DexMappingsMantle.MERCHANT_MOE_LB, pool, tokenIn, LenderMappingsMantle.LENDLE_ID, endId);
    }

    function getCloseExactInMultiLB(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        address pool = testQuoter.v2TypePairAddress(TokensMantle.USDe, tokenIn, DexMappingsMantle.MERCHANT_MOE);
        bytes memory firstPart = abi.encodePacked(tokenIn, actionId, DexMappingsMantle.MERCHANT_MOE, pool, MERCHANT_MOE_FEE_DENOM, TokensMantle.USDe);
        pool = ILBFactory(MERCHANT_MOE_LB_FACTORY).getLBPairInformation(tokenOut, TokensMantle.USDe, BIN_STEP_LOWEST).LBPair;
        return abi.encodePacked(firstPart, midId, DexMappingsMantle.MERCHANT_MOE_LB, pool, tokenOut, LenderMappingsMantle.LENDLE_ID, endId);
    }

    /**
     * DEPO AND BORROW HELPER
     */
    function _deposit(address user, address asset, uint256 amount) internal {
        deal(asset, user, amount);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amount);
        bytes memory t = transferIn(asset, brokerProxyAddress, amount);
        bytes memory d = deposit(asset, user, amount, LenderMappingsMantle.LENDLE_ID);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(abi.encodePacked(t, d));
    }

    function _borrow(address user, address asset, uint256 amount) internal {
        address debtAsset = debtTokens[asset][LenderMappingsMantle.LENDLE_ID];
        vm.prank(user);
        IERC20All(debtAsset).approveDelegation(brokerProxyAddress, amount);
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(borrow(asset, user, amount, LenderMappingsMantle.LENDLE_ID, DEFAULT_MODE));
    }
}
