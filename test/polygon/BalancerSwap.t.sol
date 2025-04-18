// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";
import "./utils/BalancerCaller.sol";
import {BalancerQuoter} from "../../contracts/1delta/modules/polygon/quoters/BalanacerQuoter.sol";

contract BalancerTestPolygon is DeltaSetup {
    // WETH / TokensPolygon.WBTC / USDC 3-pool
    address internal constant three_pool = 0x03cD191F589d12b0582a99808cf19851E468E6B5;
    bytes32 internal constant three_pool_id = 0x03cd191f589d12b0582a99808cf19851e468e6b500010000000000000000000a;

    // wMatic MaticX csp
    address internal constant cs_pool = 0xcd78A20c597E367A4e478a2411cEB790604D7c8F;
    bytes32 internal constant cs_pool_id = 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22;

    function test_polygon_balancer_exact_out() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 maxIn = 10.0e18;
        uint256 gas;
        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, three_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_OUT), user, encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length), dataBalancer);

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

        // expect 1.8 wETH for 0.1 wBTC
        assertApproxEqAbs(balanceIn, 1829207155043664215, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    /**
     * Balancer first
     */
    function test_polygon_balancer_exact_out_multi() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 maxIn = 20000.0e18;
        uint256 gas;
        address assetIn = TokensPolygon.WMATIC;
        address assetOut = TokensPolygon.WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancerMulti(assetIn, assetOut, three_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_OUT), user, encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP multi EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 11k wMATIC for 0.1 wBTC
        assertApproxEqAbs(balanceIn, 11179350804689914265669, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    /**
     * Balancer last
     */
    function test_polygon_balancer_exact_out_multi_reverse() external {
        address user = testUser;
        uint256 amount = 20000.0e18;
        uint256 maxIn = 0.2e8;
        uint256 gas;
        address assetIn = TokensPolygon.WBTC;
        address assetOut = TokensPolygon.WMATIC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancerMultiReverse(assetIn, assetOut, three_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_OUT), user, encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP multi EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 11k wMATIC for 0.1 wBTC
        assertApproxEqAbs(balanceIn, 18840052, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_polygon_balancer_exact_In() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 minOut = 1.5e18;
        uint256 gas;
        address assetIn = TokensPolygon.WBTC;
        address assetOut = TokensPolygon.WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancer(assetIn, assetOut, three_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_IN), user, encodeSwapAmountParams(amount, minOut, false, dataBalancer.length), dataBalancer);

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
        // expect 1.7 wETH for 0.1 wBTC
        assertApproxEqAbs(balanceOut, 1774720067908037858, 0);
    }

    function test_polygon_balancer_exact_out_cpool() external {
        address user = testUser;
        uint256 amount = 10_000.0e18;
        uint256 maxIn = 10_100.0e18;

        address assetIn = TokensPolygon.MaticX;
        address assetOut = TokensPolygon.WMATIC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, cs_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_OUT), user, encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 8966.06031107 MaticX for 10k wMATIC
        assertApproxEqAbs(balanceIn, 8966060311066461950276, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_polygon_balancer_exact_out_multi_cpool() external {
        address user = testUser;
        uint256 amount = 10_000.0e18;
        uint256 maxIn = 4.0e18;

        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.MaticX;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancerMultiCSP(assetIn, assetOut, cs_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_OUT), user, encodeSwapAmountParams(amount, maxIn, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP multi EO", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 1.8 TokensPolygon.WETH for 10k MaticX
        assertApproxEqAbs(balanceIn, 1828870286967801513, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_polygon_balancer_exact_in_cpool() external {
        address user = testUser;
        uint256 amount = 10_000.0e18;
        uint256 minOut = 11_100.0e18;

        address assetIn = TokensPolygon.MaticX;
        address assetOut = TokensPolygon.WMATIC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancer(assetIn, assetOut, cs_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_IN), user, encodeSwapAmountParams(amount, minOut, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas WP multi reverse EI", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 11153k wMATIC for 10k MaticX
        assertApproxEqAbs(balanceIn, amount, 0);
        assertApproxEqAbs(balanceOut, 11153162337844760556082, 0);
    }

    /**
     * Exact in MaticX -> TokensPolygon.WMATIC -> TokensPolygon.WETH
     */
    function test_polygon_balancer_exact_in_cpool_multi() external {
        address user = testUser;
        uint256 amount = 10_000.0e18;
        uint256 minOut = 1.8e18;

        address assetIn = TokensPolygon.MaticX;
        address assetOut = TokensPolygon.WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancerMulti(assetIn, assetOut, cs_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_IN), user, encodeSwapAmountParams(amount, minOut, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP multi EI", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 1.8 wETH for 10k MaticX
        assertApproxEqAbs(balanceIn, amount, 0);
        assertApproxEqAbs(balanceOut, 1821667381043385905, 0);
    }

    /**
     * Exact in MaticX -> TokensPolygon.WMATIC -> TokensPolygon.WETH
     */
    function test_polygon_balancer_exact_in_cpool_multi_reverse() external {
        address user = testUser;
        uint256 amount = 1.8e18;
        uint256 minOut = 9_770.0e18;

        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.MaticX;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancerMultiReverse(assetIn, assetOut, cs_pool_id);

        bytes memory data =
            abi.encodePacked(uint8(Commands.SWAP_EXACT_IN), user, encodeSwapAmountParams(amount, minOut, false, dataBalancer.length), dataBalancer);

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);
        uint256 balanceIn = IERC20All(assetIn).balanceOf(user);

        vm.prank(user);
        uint256 gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas CSP multi reverse EI", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 1.8 wETH for 10k MaticX
        assertApproxEqAbs(balanceIn, amount, 0);
        assertApproxEqAbs(balanceOut, 9775768444742263707409, 0);
    }

    function test_polygon_balancer_quote_csp_exact_out_cpool() external {
        BalancerQuoter q = new BalancerQuoter();
        uint256 amount = 10_000.0e18;

        address assetIn = TokensPolygon.MaticX;
        address assetOut = TokensPolygon.WMATIC;

        uint256 gas = gasleft();
        uint256 quoted = q.getAmountInCSP(cs_pool_id, assetIn, assetOut, amount);
        gas = gas - gasleft();

        console.log("gas for CSP quoting", gas);
        console.log("quoted", quoted);
        assertApproxEqAbs(quoted, 8966060311066461950276, 0);
    }

    function test_polygon_balancer_quote_wp_exact_out() external {
        BalancerQuoter q = new BalancerQuoter();

        uint256 amount = 0.1e8;

        address assetIn = TokensPolygon.WETH;
        address assetOut = TokensPolygon.WBTC;

        uint256 gas = gasleft();
        uint256 quoted = q.getAmountInWP(three_pool_id, assetIn, assetOut, amount);
        gas = gas - gasleft();

        console.log("gas for WP quoting", gas);
        console.log("quoted", quoted);
    }

    function getSpotExactOutBalancer(address tokenIn, address tokenOut, bytes32 pId) internal pure returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, DexMappingsPolygon.BALANCER, pId, tokenIn, uint8(99), uint8(99));
    }

    function getSpotExactInBalancer(address tokenIn, address tokenOut, bytes32 pId) internal pure returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, DexMappingsPolygon.BALANCER, pId, tokenOut, uint8(99), uint8(99));
    }

    /**
     * UniswapV3 -> BalancerV2 WP exactOut
     */
    function getSpotExactOutBalancerMulti(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = 500;
        address pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.WETH, fee, DexMappingsPolygon.UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenOut, action, DexMappingsPolygon.BALANCER, pId, TokensPolygon.WETH);
        }
        return abi.encodePacked(firstPart, action, DexMappingsPolygon.UNI_V3, pool, fee, tokenIn, uint8(99), uint8(99));
    }

    /**
     * BalancerV2 CSP -> UniswapV3 exactIn
     */
    function getSpotExactInBalancerMulti(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = 3000;
        address pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.WMATIC, fee, DexMappingsPolygon.UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenIn, action, DexMappingsPolygon.BALANCER, pId, TokensPolygon.WMATIC);
        }
        return abi.encodePacked(firstPart, action, DexMappingsPolygon.UNI_V3, pool, fee, tokenOut, uint8(99), uint8(99));
    }

    /**
     * UniswapV3 -> BalancerV2 CSP exactIn
     */
    function getSpotExactInBalancerMultiReverse(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = 3000;
        address pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.WMATIC, fee, DexMappingsPolygon.UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenIn, action, DexMappingsPolygon.UNI_V3, pool, fee, TokensPolygon.WMATIC);
        }
        return abi.encodePacked(firstPart, action, DexMappingsPolygon.BALANCER, pId, tokenOut, uint8(99), uint8(99));
    }

    /**
     * BalancerV2 WP -> UniswapV3  exactOut
     */
    function getSpotExactOutBalancerMultiReverse(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = 3000;
        address pool = testQuoter.v3TypePool(tokenOut, TokensPolygon.WETH, fee, DexMappingsPolygon.UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenOut, action, DexMappingsPolygon.UNI_V3, pool, fee, TokensPolygon.WETH);
        }
        return abi.encodePacked(firstPart, action, DexMappingsPolygon.BALANCER, pId, tokenIn, uint8(99), uint8(99));
    }

    /**
     * UniswapV3 -> BalancerV2 CSP exactOut
     */
    function getSpotExactOutBalancerMultiCSP(address tokenIn, address tokenOut, bytes32 pId) internal view returns (bytes memory data) {
        uint8 action = 0;
        uint16 fee = 500;
        address pool = testQuoter.v3TypePool(tokenIn, TokensPolygon.WMATIC, fee, DexMappingsPolygon.UNI_V3);

        bytes memory firstPart;
        {
            firstPart = abi.encodePacked(tokenOut, action, DexMappingsPolygon.BALANCER, pId, TokensPolygon.WMATIC);
        }
        return abi.encodePacked(firstPart, action, DexMappingsPolygon.UNI_V3, pool, fee, tokenIn, uint8(99), uint8(99));
    }
}
