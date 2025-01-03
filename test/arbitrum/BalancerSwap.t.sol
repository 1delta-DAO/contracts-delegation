// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";
import "./utils/BalancerCaller.sol";
import {BalancerQuoter} from "../../contracts/1delta/modules/polygon/quoters/BalanacerQuoter.sol";

contract BalancerTestArbitrum is DeltaSetup {
    // ezETH / wstETH 2-pool
    bytes32 internal constant two_pool_id = 0xb61371ab661b1acec81c699854d2f911070c059e000000000000000000000516;

    // Balancer sFRAX/4POOL StablePool
    bytes32 internal constant cs_pool_id = 0x423a1323c871abc9d89eb06855bf5347048fc4a5000000000000000000000496;

    function test_arbitrum_balancer_exact_out() external {
        address user = testUser;
        uint256 amount = 10.0e18;
        uint256 maxIn = 10.0e18;
        uint gas;
        address assetIn = TokensArbitrum.WSTETH;
        address assetOut = TokensArbitrum.EZETH;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, two_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 8.6 wtETH for 10 ezETH
        assertApproxEqAbs(balanceIn, 8675843192762582288, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_arbitrum_balancer_exact_In() external {
        address user = testUser;
        uint256 amount = 1.0e18;
        uint256 minOut = 1.0e18;
        uint gas;
        address assetIn = TokensArbitrum.WSTETH;
        address assetOut = TokensArbitrum.EZETH;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancer(assetIn, assetOut, two_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, minOut, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP EI", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);
        assertApproxEqAbs(balanceIn, amount, 0);
        // expect 1 wstETH for 1.15 ezETH
        assertApproxEqAbs(balanceOut, 1152654641677102821, 0);
    }

    function test_arbitrum_balancer_exact_out_cpool() external {
        address user = testUser;
        uint256 amount = 10.0e6;
        uint256 maxIn = 10.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, cs_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 9.9 USDC for 10 USDT
        assertApproxEqAbs(balanceIn, 9980093, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_arbitrum_balancer_exact_out_multi_cpool() external {
        address user = testUser;
        uint256 amount = 1000.0e6;
        uint256 maxIn = 0.31e18;

        address assetIn = TokensArbitrum.WETH;
        address assetOut = TokensArbitrum.USDC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancerMultiCSP(assetIn, assetOut, cs_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            user,
            encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP multi EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 0.31 USDC for 1k USDC
        assertApproxEqAbs(balanceIn, 300737510718097939, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_arbitrum_balancer_exact_in_cpool() external {
        address user = testUser;
        uint256 amount = 1000.0e6;
        uint256 minOut = 1001.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancer(assetIn, assetOut, cs_pool_id);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, minOut, false, dataBalancer.length),
            dataBalancer
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP multi reverse EI", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 1001 USDT for 1k USDT
        assertApproxEqAbs(balanceIn, amount, 0);
        assertApproxEqAbs(balanceOut, 1001876176, 0);
    }

    function getSpotExactOutBalancer(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, BALANCER_V2_DEXID, pId, tokenIn, uint8(99), uint8(99));
    }

    function getSpotExactInBalancer(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, BALANCER_V2_DEXID, pId, tokenOut, uint8(99), uint8(99));
    }

    /** UniswapV3 -> BalancerV2 CSP exactOut */
    function getSpotExactOutBalancerMultiCSP(
        address tokenIn,
        address tokenOut,
        bytes32 pId
    ) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = DEX_FEE_STABLES;
        address pool = testQuoter._v3TypePool(tokenIn, TokensArbitrum.USDT, fee, UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenOut, action, BALANCER_V2_DEXID, pId, TokensArbitrum.USDT);
        }
        return abi.encodePacked(firstPart, action, UNI_V3, pool, fee, tokenIn, uint8(99), uint8(99));
    }
}
