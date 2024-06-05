// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ComposerTest is DeltaSetup {
    uint8 SWAP_EXACT_IN = 0x0;

    function test_composer_depo() external {
        address user = testUser;
        uint256 amount = 10.0e6;
        deal(USDT, user, 1e23);

        vm.prank(user);
        IERC20All(USDT).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = abi.encodePacked(
            uint8(0x12),
            uint16(72),
            USDT,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = abi.encodePacked(
            uint8(3),
            uint16(72), // redundant
            USDT,
            user,
            amount //
        );
        data = abi.encodePacked(transfer, data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_multi_route_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(assetIn, assetOut, AGNI);
        bytes memory dataFusion = getSpotExactInSingleGen2(assetIn, assetOut, FUSION_X);
        bytes memory data = abi.encodePacked(
            SWAP_EXACT_IN,
            uint16(dataAgni.length + 52), // begin agni data
            amount / 2,
            user,
            dataAgni,
            SWAP_EXACT_IN,
            uint16(dataFusion.length + 52), // begin fusionX data
            amount / 2,
            user,
            dataFusion
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, fee, tokenOut);
    }
}
