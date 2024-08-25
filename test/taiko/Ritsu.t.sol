// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

interface ISwap {
    function getAmountIn(
        address _tokenOut, //
        uint _amountOut,
        address _sender
    ) external view returns (uint _amountIn);

    function getAmountOut(
        address _tokenIn, //
        uint _amountIn,
        address _sender
    ) external view returns (uint _amountOut);

    function master() external view returns (address);

    function symbol() external view returns (string memory);

    function getReserves() external view returns (uint _reserve0, uint _reserve1);

    function getSwapFee(
        address _sender,
        address _tokenIn,
        address _tokenOut, //
        bytes memory data
    ) external view returns (uint24 _swapFee);
}

contract TitsuTestTaiko is DeltaSetup {
    uint8 internal constant RITSU = 150;
    address internal constant USDC_WETH_RITSU_POOL = 0x424Fab7bfA3E3Dd0e5BB96771fFAa72fe566200e;
    address internal constant USDC_sgUSDC_RITSU_POOL = 0x6c7839E0CE8AdA360a865E18a111A462d08DC15a;

    function test_taiko_composer_ritsu_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.3e18;

        address assetIn = USDC;
        address assetOut = WETH;
        deal(assetIn, user, 1e23);
        address pool = USDC_WETH_RITSU_POOL;
        uint expectedOut = ISwap(pool).getAmountOut(assetIn, amount, address(0));
        console.log("ISwap.master f", testQuoter._syncClassicPairAddress(assetIn, assetOut));

        bytes memory dataRitsu = getSpotExactInSingleGen2(assetIn, assetOut, RITSU, pool);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataRitsu.length),
            dataRitsu
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint received = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 0.7369 WETH
        assertApproxEqAbs(expectedOut, received, 1);
        assertApproxEqAbs(expectedOut, 736925511614964287, 1);
    }

    function test_taiko_composer_ritsu_multi_exact_in() external {
        address user = testUser;
        uint256 amount = 20.0e6;
        uint256 amountMin = 0.3e18;

        address assetIn = USDC;
        address assetOut = TAIKO;
        deal(assetIn, user, 1e23);

        bytes memory dataRitsu = getSpotExactInMultiGen2(assetIn, assetOut);

        uint256 expectedOut = testQuoter.quoteExactInput(
            getQuoteSpotExactInMultiGen2(assetIn, assetOut),
            amount //
        );

        console.log("expected", expectedOut);
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataRitsu.length),
            dataRitsu
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint received = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 0.7369 WETH
        assertApproxEqAbs(expectedOut, received, 1);
        assertApproxEqAbs(expectedOut, 10572763709453061122, 1);
    }

    function test_taiko_composer_ritsu_exact_in_stable() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 1900.3e6;

        address assetIn = USDC;
        address assetOut = sgUSDC;
        deal(assetIn, user, 1e23);
        address pool = USDC_sgUSDC_RITSU_POOL;
        uint expectedOut = ISwap(pool).getAmountOut(assetIn, amount, address(0));
        console.log("ISwap.master f", testQuoter._syncStablePairAddress(assetIn, assetOut));

        bytes memory dataRitsu = getSpotExactInSingleGen2(assetIn, assetOut, RITSU, pool);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataRitsu.length),
            dataRitsu
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint received = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 1998.436046 sgUSDC
        assertApproxEqAbs(expectedOut, received, 1);
        assertApproxEqAbs(expectedOut, 1998436046, 1);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, address pool) internal view returns (bytes memory data) {
        {
            (uint r0, uint r1) = ISwap(pool).getReserves();
            uint sf = ISwap(pool).getSwapFee(tokenIn, tokenOut, address(0), "");
            console.log("reserve0:", r0);
            console.log("reserve1:", r1);
            console.log("swapFee:", sf);
            console.log("symb:", ISwap(pool).symbol());
        }
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, tokenOut);
    }

    function getSpotExactInMultiGen2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter._syncBasePairAddress(tokenIn, WETH);
        uint8 action = 0;
        uint8 poolId = RITSU;
        data = abi.encodePacked(tokenIn, action, poolId, pool, WETH);
        poolId = KODO_VOLAT;
        pool = testQuoter._v2TypePairAddress(WETH, tokenOut, poolId);
        data = abi.encodePacked(data, action, poolId, pool, KODO_VOLAT_FEE_DENOM, tokenOut);
    }

    function getQuoteSpotExactInMultiGen2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        address pool = testQuoter._syncBasePairAddress(tokenIn, WETH);
        uint8 poolId = RITSU;
        data = abi.encodePacked(tokenIn, poolId, pool, WETH);
        poolId = KODO_VOLAT;
        pool = testQuoter._v2TypePairAddress(WETH, tokenOut, poolId);
        data = abi.encodePacked(data, poolId, pool, KODO_VOLAT_FEE_DENOM, tokenOut);
    }
}