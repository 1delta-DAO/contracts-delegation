// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

/**
 * We test flash swap executions using exact in trade types (given that the first pool supports flash swaps)
 * These are always applied on margin, however, we make sure that we always get
 * The expected amounts. Exact out swaps always execute flash swaps whenever possible.
 */
contract FlashSwapExacInTest is DeltaSetup {
    uint8 ZERO_8 = 0;

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 63740637, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    ////////////////////////////////////////////////////
    // Flash swap, V4 - Curve (with gain)
    ////////////////////////////////////////////////////

    function test_mantle_stratum_arb_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = WETH;

        uint256 amountIn = 1.0e18;
        uint256 minimumOut = amountIn;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInSingleStratumMETHQuoter(WETH), amountIn);

        bytes memory swapPath = getSpotExactInSingleStratumMETH(asset);

        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            data,
            sweep(
                assetOut,
                user,
                0, //
                ComposerUtils.SweepType.VALIDATE
            )
        );
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        // This amount should be positive if there is extractable arbitrage
        assetBalance = IERC20All(asset).balanceOf(user) - assetBalance;

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(quoted - amountIn, assetBalance, 0);
    }

    ////////////////////////////////////////////////////
    // Flash swap, V2 - Curve (with loss, we inject the residual amount)
    ////////////////////////////////////////////////////

    function test_mantle_stratum_arb_exact_in_v2() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = WETH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2(WETH), amountIn);
        uint256 minimumOut = quoted;

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2(asset);

        // since we use MerchantMode, we expect a loss inn execution, we have to contribute this amount
        uint256 residual = quoted >= amountIn ? 0 : amountIn - quoted;

        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            transferIn(
                asset,
                brokerProxyAddress, // transfer in
                residual
            ), //
            data,
            sweep(
                assetOut,
                user,
                0, // no minOut
                ComposerUtils.SweepType.VALIDATE
            )
        );

        deal(asset, user, residual);

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(asset).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        // This amount should be positive if there is a loss
        assetBalance = assetBalance - IERC20All(asset).balanceOf(user);

        // swap 5, receive approx 4.9, but in 18 decs
        assertApproxEqAbs(quoted, amountIn - assetBalance, 0);
    }

    ////////////////////////////////////////////////////
    // Flash swap, V3 - Curve - V2 (with loss, we inject the residual amount)
    ////////////////////////////////////////////////////

    function test_mantle_stratum_arb_exact_in_v2_3_pools() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = METH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools(WETH), amountIn);

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2_3Pool(asset);

        deal(asset, user, amountIn);

        uint256 minimumOut = quoted;

        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            transferIn(
                asset,
                brokerProxyAddress, // transfer in
                amountIn
            ), //
            data,
            sweep(
                assetOut,
                user,
                0, // no minOut
                ComposerUtils.SweepType.VALIDATE
            )
        );

        // calls[2] = abi.encodeWithSelector(ILending.sweep.selector, assetOut);
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assetBalance = IERC20All(assetOut).balanceOf(user) - assetBalance;

        assertApproxEqAbs(quoted, assetBalance, 0);
    }

    ////////////////////////////////////////////////////
    // Flash swap, V2 - Curve - V3 (with loss, we inject the residual amount)
    ////////////////////////////////////////////////////

    function test_mantle_stratum_arb_exact_in_v2_3_pools_V3Last() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = METH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools_V3Last(WETH), amountIn);

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2_3Pool_V3Last(asset);

        deal(asset, user, amountIn);

        uint256 minimumOut = quoted;
        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            transferIn(
                asset,
                brokerProxyAddress, // transfer in
                amountIn
            ), //
            data,
            sweep(
                assetOut,
                user,
                0, // no minOut
                ComposerUtils.SweepType.VALIDATE
            )
        );
        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assetBalance = IERC20All(assetOut).balanceOf(user) - assetBalance;

        assertApproxEqAbs(quoted, assetBalance, 0);
    }

    ////////////////////////////////////////////////////
    // Same as the two last ones above, the swap is
    // triggered with the spot varaint
    ////////////////////////////////////////////////////

    function test_mantle_stratum_arb_exact_in_v2_3_pools_spot() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = METH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools(WETH), amountIn);

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2_3Pool(asset);

        deal(asset, user, amountIn);

        uint256 minimumOut = quoted;
        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            transferIn(
                asset,
                brokerProxyAddress, // transfer in
                amountIn
            ), //
            data,
            sweep(
                assetOut,
                user,
                0, // no minOut
                ComposerUtils.SweepType.VALIDATE
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assetBalance = IERC20All(assetOut).balanceOf(user) - assetBalance;

        assertApproxEqAbs(quoted, assetBalance, 0);
    }

    function test_mantle_stratum_arb_exact_in_v2_3_pools_V3Last_spot() external {
        address user = testUser;
        vm.assume(user != address(0));
        address asset = WETH;
        address assetOut = METH;

        uint256 amountIn = 1.0e18;

        uint256 quoted = testQuoter.quoteExactInput(getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools_V3Last(WETH), amountIn);

        bytes memory swapPath = getSpotExactInDoubleStratumMETHV2_3Pool_V3Last(asset);

        deal(asset, user, amountIn);

        uint256 minimumOut = quoted;
        bytes memory data = abi.encodePacked(
            uint8(Commands.FLASH_SWAP_EXACT_IN),
            encodeSwapAmountParams(amountIn, minimumOut, true, swapPath.length),
            swapPath
        );
        data = abi.encodePacked(
            transferIn(
                asset,
                brokerProxyAddress, // transfer in
                amountIn
            ), //
            data,
            sweep(
                assetOut,
                user,
                0, // no minOut
                ComposerUtils.SweepType.VALIDATE
            )
        );

        vm.prank(user);
        IERC20All(asset).approve(brokerProxyAddress, amountIn);

        uint256 assetBalance = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        assetBalance = IERC20All(assetOut).balanceOf(user) - assetBalance;

        assertApproxEqAbs(quoted, assetBalance, 0);
    }

    /** PATH BUILDERS */

    function getTokenIdEth(address t) internal view returns (uint8) {
        if (t == METH) return 1;
        else return 0;
    }

    function getSpotExactInAgni(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = AGNI;
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, ZERO_8, poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleStratumMETH(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInAgni(token, METH),
                ZERO_8,
                STRATUM_CURVE,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token)),
                token
            );
    }

    function getSpotExactInAgniQuoter(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, DEX_FEE_STABLES, AGNI);
        return abi.encodePacked(tokenIn, AGNI, pool, DEX_FEE_STABLES, tokenOut);
    }

    function getSpotExactInMoeQuoter(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, MERCHANT_MOE);
        return abi.encodePacked(tokenIn, MERCHANT_MOE, pool, MERCHANT_MOE_FEE_DENOM, tokenOut);
    }

    function getSpotExactInSingleStratumMETHQuoter(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInAgniQuoter(token, METH),
                STRATUM_CURVE,
                abi.encodePacked(STRATUM_ETH_POOL, getTokenIdEth(METH), getTokenIdEth(token)),
                token
            );
    }

    function getSpotExactInDoubleStratumMETHV2_3Pool(address token) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(token, METH, poolId);
        return
            abi.encodePacked(
                getSpotExactInAgni(token, METH),
                ZERO_8, 
                STRATUM_CURVE,
                abi.encodePacked(STRATUM_ETH_POOL, getTokenIdEth(METH), getTokenIdEth(token)),
                token,
                abi.encodePacked(ZERO_8, MERCHANT_MOE, pool, MERCHANT_MOE_FEE_DENOM, METH)
            );
    }

    function getSpotExactInDoubleStratumMETHV2_3Pool_V3Last(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInMoe(token, METH),
                ZERO_8, // action
                STRATUM_CURVE,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token)),
                getSpotExactInAgni(token, METH)
            );
    }

    function getSpotExactInDoubleStratumMETHV2(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInMoe(token, METH),
                ZERO_8, // action
                STRATUM_CURVE,
                STRATUM_ETH_POOL,
                abi.encodePacked(getTokenIdEth(METH), getTokenIdEth(token)),
                token
            );
    }

    function getSpotExactInMoe(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = MERCHANT_MOE;
        address pool = testQuoter._v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, ZERO_8, poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut);
    }

    function getSpotExactInDoubleStratumMETHQuoterWithV2(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInMoeQuoter(token, METH),
                STRATUM_CURVE,
                abi.encodePacked(STRATUM_ETH_POOL, getTokenIdEth(METH), getTokenIdEth(token)),
                token
            );
    }

    function getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInAgniQuoter(token, METH),
                STRATUM_CURVE,
                abi.encodePacked(STRATUM_ETH_POOL, getTokenIdEth(METH), getTokenIdEth(token)),
                token,
                abi.encodePacked(MERCHANT_MOE, testQuoter._v2TypePairAddress(token, METH, MERCHANT_MOE), MERCHANT_MOE_FEE_DENOM, METH)
            );
    }

    function getSpotExactInDoubleStratumMETHQuoterWithV2_3Pools_V3Last(address token) internal view returns (bytes memory data) {
        return
            abi.encodePacked(
                getSpotExactInMoeQuoter(token, METH),
                STRATUM_CURVE,
                abi.encodePacked(STRATUM_ETH_POOL, getTokenIdEth(METH), getTokenIdEth(token)),
                getSpotExactInAgniQuoter(token, METH)
            );
    }
}
