// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SwapGen2Test is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_mantle_gen_2_spot_exact_in() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 2000.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(amountToSwap, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_in_v2_fusion_pure() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.WMNT;

        address assetTo = TokensMantle.LEND;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 20.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2FusionX(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(address(aggregator), amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        aggregator.deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(178522773, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToReceive = 2000.0e6;

        bytes memory swapPath = getSpotExactOutSingleGen2(assetFrom, assetTo);
        uint256 maximumIn = 2300.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 2000330778, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_v2() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.WMNT;
        deal(assetFrom, user, 1e20);

        uint256 amountToReceive = 20.0e18;

        bytes memory swapPath = getSpotExactOutSingleV2Gen2(assetFrom, assetTo);
        uint256 maximumIn = 33.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 30109865, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_in_solidly() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.aUSD;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 2000.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2Solidly(assetFrom, assetTo);
        console.log("ts");
        uint256 minimumOut = 1900.0e18;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(1976074699820208374246, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_solidly() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.aUSD;
        deal(assetFrom, user, 1e20);

        uint256 amountToReceive = 2000.0e18;

        bytes memory swapPath = getSpotExactOutSingleSolidlyGen2(assetFrom, assetTo);
        uint256 maximumIn = 2300.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 2024300011, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_multi() external {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToReceive = 1.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3ExactOut();

        deal(assetFrom, user, 1e20);

        uint256 maximumIn = 6.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 1090371, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_out_multi_mixed() external {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToReceive = 1.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixedExectOut();

        deal(assetFrom, user, 1e20);

        uint256 maximumIn = 6.0e6;
        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, maximumIn);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_OUT,
            user,
            amountToReceive, //
            maximumIn,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, 1003277, 0);
        assertApproxEqAbs(amountToReceive, balanceOut, 1e6);
    }

    function test_mantle_gen_2_spot_exact_in_multi() external {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToSwap = 2.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensV3();

        deal(assetFrom, user, 1e20);

        uint256 minimumOut = 1.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();

        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // loses 0.2 TokensMantle.USDT on the trade (due to low liquidity)
        assertApproxEqAbs(1993355, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_multi_mixed() external {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToSwap = 2.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixed();

        deal(assetFrom, user, 1e20);

        uint256 minimumOut = 1.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();

        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // loses 0.2 TokensMantle.USDT on the trade (due to low liquidity)
        assertApproxEqAbs(1990518, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_multi_mixed_exotic() external {
        address user = testUser;
        vm.assume(user != address(0));

        uint256 amountToSwap = 1.0e6;

        (address assetFrom, address assetTo, bytes memory swapPath) = getPathAndTokensMixedExotic();

        deal(assetFrom, user, 1.0e20);

        uint256 minimumOut = 0.9e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();

        console.log("gas", gas);

        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        // swaps 1 TokensMantle.USDT for 0.98 TokensMantle.USDT
        assertApproxEqAbs(986191, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_V2() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.USDT;
        deal(assetFrom, user, 1e20);

        uint256 amountToSwap = 200.0e6;

        bytes memory swapPath = getSpotExactInSingleGen2V2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            amountToSwap, //
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(198751420, balanceOut, 1);
    }

    function test_mantle_gen_2_spot_exact_in_V2_all() external {
        address user = testUser;
        vm.assume(user != address(0));
        address assetFrom = TokensMantle.USDC;

        address assetTo = TokensMantle.USDT;
        uint256 amountToSwap = 200.0e6;
        deal(assetFrom, user, amountToSwap);

        bytes memory swapPath = getSpotExactInSingleGen2V2(assetFrom, assetTo);
        uint256 minimumOut = 10.0e6;

        vm.prank(user);
        IERC20All(assetFrom).approve(brokerProxyAddress, amountToSwap);

        uint256 balanceIn = IERC20All(assetFrom).balanceOf(user);
        uint256 balanceOut = IERC20All(assetTo).balanceOf(user);
        bytes memory data = encodeSwap(
            Commands.SWAP_EXACT_IN,
            user,
            0, // all
            minimumOut,
            false,
            swapPath
        );
        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
        balanceOut = IERC20All(assetTo).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetFrom).balanceOf(user);
        assertApproxEqAbs(balanceIn, amountToSwap, 0);
        assertApproxEqAbs(198751420, balanceOut, 1);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactInSingleGen2FusionX(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.FUSION_X_V2;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(
            tokenIn,
            uint8(0),
            poolId,
            pool,
            getV2PairFeeDenom(poolId, pool), //
            tokenOut
        );
    }

    function getSpotExactOutSingleGen2(address tokenOut, address tokenIn) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        uint8 poolId = DexMappingsMantle.AGNI;
        address pool = testQuoter.v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleSolidlyGen2(address tokenOut, address tokenIn) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.CLEO_V1_STABLE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(
            tokenIn,
            uint8(0),
            poolId,
            pool,
            getV2PairFeeDenom(poolId, pool), //
            tokenOut
        );
    }

    function getSpotExactOutSingleV2Gen2(address tokenOut, address tokenIn) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(
            tokenIn,
            uint8(0),
            poolId,
            pool,
            getV2PairFeeDenom(poolId, pool), //
            tokenOut
        );
    }

    function getPathDataV3()
        internal
        pure
        returns (
            //
            address[] memory tokens,
            uint8[] memory actions,
            uint8[] memory pIds,
            uint16[] memory fees
        )
    {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = TokensMantle.USDC;
        tokens[1] = TokensMantle.WMNT;
        tokens[2] = TokensMantle.WETH;
        tokens[3] = TokensMantle.USDT;
        pIds[0] = DexMappingsMantle.CLEOPATRA_CL;
        pIds[1] = DexMappingsMantle.AGNI;
        pIds[2] = DexMappingsMantle.AGNI;
        actions[0] = 0;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 250;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataV3ExactOut()
        internal
        pure
        returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees)
    {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = TokensMantle.USDC;
        tokens[1] = TokensMantle.WMNT;
        tokens[2] = TokensMantle.WETH;
        tokens[3] = TokensMantle.USDT;
        pIds[0] = DexMappingsMantle.FUSION_X;
        pIds[1] = DexMappingsMantle.AGNI;
        pIds[2] = DexMappingsMantle.AGNI;
        actions[0] = 0;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataMixed() internal pure returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = TokensMantle.USDC;
        tokens[1] = TokensMantle.WMNT;
        tokens[2] = TokensMantle.WETH;
        tokens[3] = TokensMantle.USDT;
        pIds[0] = DexMappingsMantle.MERCHANT_MOE;
        pIds[1] = DexMappingsMantle.AGNI;
        pIds[2] = DexMappingsMantle.AGNI;
        actions[0] = 0;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getPathDataMixedExotic()
        internal
        pure
        returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees)
    {
        uint256 length = 5;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = TokensMantle.USDC;
        tokens[1] = TokensMantle.USDT;
        tokens[2] = TokensMantle.WMNT;
        tokens[3] = TokensMantle.WETH;
        tokens[4] = TokensMantle.USDT;
        pIds[0] = DexMappingsMantle.AGNI;
        pIds[1] = DexMappingsMantle.KTX;
        pIds[2] = DexMappingsMantle.MERCHANT_MOE;
        pIds[3] = DexMappingsMantle.MERCHANT_MOE;
        actions[0] = 0;
        actions[1] = 0;
        actions[2] = 0;
        actions[3] = 0;
        fees[0] = 100;
        fees[1] = 0;
        fees[2] = 500;
        fees[3] = 500;
    }

    function getPathDataMixedExactOut()
        internal
        pure
        returns (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees)
    {
        uint256 length = 4;
        uint256 lengthDecreased = length - 1;
        tokens = new address[](length);
        actions = new uint8[](lengthDecreased);
        pIds = new uint8[](lengthDecreased);
        fees = new uint16[](lengthDecreased);
        tokens[0] = TokensMantle.USDC;
        tokens[1] = TokensMantle.WMNT;
        tokens[2] = TokensMantle.WETH;
        tokens[3] = TokensMantle.USDT;
        pIds[0] = DexMappingsMantle.MERCHANT_MOE;
        pIds[1] = DexMappingsMantle.AGNI;
        pIds[2] = DexMappingsMantle.AGNI;
        actions[0] = 0;
        actions[1] = 0;
        actions[2] = 0;
        fees[0] = 2500;
        fees[1] = 500;
        fees[2] = 500;
    }

    function getSpotSingleGen2Mixed(
        address[] memory tokens,
        uint8[] memory actions,
        uint8[] memory pIds,
        uint16[] memory fees
    )
        internal
        view
        returns (bytes memory path)
    {
        path = abi.encodePacked(tokens[0]);
        for (uint256 i = 1; i < tokens.length; i++) {
            uint8 pId = pIds[i - 1];
            if (pId <= DexMappingsMantle.UNISWAP_V3_MAX_ID) {
                address pool = testQuoter.v3TypePool(tokens[i - 1], tokens[i], fees[i - 1], pId);
                path = abi.encodePacked(path, actions[i - 1], pId, pool, fees[i - 1], tokens[i]);
            } else if (pId < 100) {
                path = abi.encodePacked(path, actions[i - 1], pId, tokens[i]);
            } else if (pId == DexMappingsMantle.WOO_FI) {
                path = abi.encodePacked(path, actions[i - 1], pId, WOO_POOL, tokens[i]);
            } else if (pId == DexMappingsMantle.KTX) {
                path = abi.encodePacked(path, actions[i - 1], pId, KTX_VAULT, tokens[i]);
            } else {
                address pool = testQuoter.v2TypePairAddress(tokens[i - 1], tokens[i], pId);
                path = abi.encodePacked(
                    path,
                    actions[i - 1],
                    pId,
                    pool,
                    getV2PairFeeDenom(pId, pool), //
                    tokens[i]
                );
            }
        }
    }

    function getPathAndTokensMixed() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixed();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensMixedExotic() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixedExotic();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensV3() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataV3();
        return (
            tokens[0],
            tokens[tokens.length - 1],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensV3ExactOut() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataV3ExactOut();
        return (
            tokens[tokens.length - 1],
            tokens[0],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getPathAndTokensMixedExectOut() internal view returns (address tokenIn, address tokenOut, bytes memory path) {
        (address[] memory tokens, uint8[] memory actions, uint8[] memory pIds, uint16[] memory fees) = getPathDataMixedExactOut();
        return (
            tokens[tokens.length - 1],
            tokens[0],
            getSpotSingleGen2Mixed(tokens, actions, pIds, fees) //
        );
    }

    function getSpotExactInSingleGen2V2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.MERCHANT_MOE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, MERCHANT_MOE_FEE_DENOM, tokenOut);
    }

    function getSpotExactInSingleGen2Solidly(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint8 poolId = DexMappingsMantle.CLEO_V1_STABLE;
        address pool = testQuoter.v2TypePairAddress(tokenIn, tokenOut, poolId);
        return abi.encodePacked(
            tokenIn,
            uint8(0),
            poolId,
            pool,
            getV2PairFeeDenom(poolId, pool), //
            tokenOut
        );
    }
}
