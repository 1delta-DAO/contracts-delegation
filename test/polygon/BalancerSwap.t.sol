// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";
import "./utils/BalancerCaller.sol";

contract CurveTestPolygon is DeltaSetup {
    // WETH / WBTC / USDC 3-pool
    address internal constant three_pool = 0x03cD191F589d12b0582a99808cf19851E468E6B5;
    bytes32 internal constant three_pool_id = 0x03cd191f589d12b0582a99808cf19851e468e6b500010000000000000000000a;

    // wMatic MaticX csp
    address internal constant cs_pool = 0xcd78A20c597E367A4e478a2411cEB790604D7c8F;
    bytes32 internal constant cs_pool_id = 0xcd78a20c597e367a4e478a2411ceb790604d7c8f000000000000000000000c22;

    function test_polygon_balancer_exact_out() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 maxIn = 10.0e18;
        uint gas;
        address assetIn = WETH;
        address assetOut = WBTC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, three_pool_id, 1);

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
        console.log("gas", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 1.8 wETH for 0.1 wBTC
        assertApproxEqAbs(balanceIn, 1829207155043664215, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function test_polygon_balancer_exact_In() external {
        address user = testUser;
        uint256 amount = 0.1e8;
        uint256 minOut = 1.50e18;
        uint gas;
        address assetIn = WBTC;
        address assetOut = WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactInBalancer(assetIn, assetOut, three_pool_id, 1);

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
        console.log("gas", gas);

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

        address assetIn = MaticX;
        address assetOut = WMATIC;
        deal(assetIn, user, 1e23);

        bytes memory dataBalancer = getSpotExactOutBalancer(assetIn, assetOut, cs_pool_id, 1);

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
        console.log("gas", gas);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - IERC20All(assetIn).balanceOf(user);

        // expect 8966.06031107 MaticX for 10k wMATIC
        assertApproxEqAbs(balanceIn, 8966060311066461950276, 0);
        assertApproxEqAbs(balanceOut, amount, 0);
    }

    function getSpotExactOutBalancer(address tokenIn, address tokenOut, bytes32 pId, uint8 preActionFlag) internal view returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenOut, action, BALANCER_V2_DEXID, pId, preActionFlag, tokenIn, uint8(99), uint8(99));
    }

    function getSpotExactInBalancer(address tokenIn, address tokenOut, bytes32 pId, uint8 preActionFlag) internal view returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, BALANCER_V2_DEXID, pId, preActionFlag, tokenOut, uint8(99), uint8(99));
    }
}
