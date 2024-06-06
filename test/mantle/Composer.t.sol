// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ComposerTest is DeltaSetup {
    uint8 DEAULT_MODE = 2;
    uint8 SWAP_EXACT_IN = 0x0;
    uint256 private constant USE_PERMIT2_FLAG = 1 << 127;
    uint256 private constant UNWRAP_NATIVE_MASK = 1 << 254;
    uint256 private constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    uint256 private constant UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;
    uint256 private constant LENDER_ID_MASK = 0x0000000000000000000000000000000000ff0000000000000000000000000000;

    function populateAmountDeposit(uint8 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function populateAmountBorrow(uint8 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountRepay(uint8 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountWithdraw(uint8 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function test_mantle_composer_depo() external {
        uint8 lenderId = 1;
        address user = testUser;
        uint256 amount = 10.0e6;
        deal(USDT, user, 1e23);

        vm.prank(user);
        IERC20All(USDT).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = abi.encodePacked(
            uint8(0x15),
            uint16(72),
            USDT,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = abi.encodePacked(
            uint8(0x13), // 1
            uint16(55), // redundant, 2
            USDT, // 20
            user, // 20
            populateAmountDeposit(lenderId, amount) // 15
        );
        data = abi.encodePacked(transfer, data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_composer_borrow() external {
        uint8 lenderId = 0;
        address user = testUser;
        uint256 amount = 10.0e6;
        address asset = USDT;

        _deposit(asset, user, amount, lenderId);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        uint256 borrowAmount = 5.0e6;

        address borrowAsset = USDC;
        vm.prank(user);
        IERC20All(debtTokens[borrowAsset][lenderId]).approveDelegation(
            address(brokerProxyAddress), //
            borrowAmount
        );

        bytes memory data = abi.encodePacked(
            uint8(0x11), // 1
            uint16(55), // redundant, 2
            borrowAsset, // 20
            user, // 20
            populateAmountBorrow(lenderId, DEAULT_MODE, borrowAmount) // 16
        );

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_composer_repay() external {
        uint8 lenderId = 0;
        address user = testUser;

        uint256 amount = 10.0e6;
        address asset = USDT;

        uint256 borrowAmount = 5.0e6;
        address borrowAsset = USDC;

        _deposit(asset, user, amount, lenderId);

        _borrow(borrowAsset, user, borrowAmount, lenderId);

        uint256 repayAmount = 2.50e6;

        bytes memory transfer = abi.encodePacked(
            uint8(0x15),
            uint16(72),
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );

        bytes memory data = abi.encodePacked(
            uint8(0x18), // 1
            uint16(56), // redundant, 2
            borrowAsset, // 20
            user, // 20
            populateAmountRepay(lenderId, DEAULT_MODE, repayAmount) // 16
        );
        data = abi.encodePacked(transfer, data);

        vm.prank(user);
        IERC20All(borrowAsset).approve(address(brokerProxyAddress), repayAmount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_composer_withdraw() external {
        uint8 lenderId = 0;
        address user = testUser;

        uint256 amount = 10.0e6;
        address asset = USDT;

        _deposit(asset, user, amount, lenderId);

        uint256 withdrawAmount = 2.50e6;

        bytes memory data = abi.encodePacked(
            uint8(0x17), // 1
            uint16(56), // redundant, 2
            asset, // 20
            user, // 20
            populateAmountWithdraw(lenderId, withdrawAmount) // 16
        );

        vm.prank(user);
        IERC20All(collateralTokens[asset][lenderId]).approve(address(brokerProxyAddress), withdrawAmount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_composer_multi_route_exact_in() external {
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

    function _deposit(address asset, address user, uint256 amount, uint8 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = abi.encodePacked(
            uint8(0x15),
            uint16(72),
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = abi.encodePacked(
            uint8(0x13), // 1
            uint16(56), // redundant, 2
            asset, // 20
            user, // 20
            populateAmountDeposit(lenderId, amount) // 15
        );
        data = abi.encodePacked(transfer, data);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function _borrow(address borrowAsset, address user, uint256 borrowAmount, uint8 lenderId) internal {
        vm.prank(user);
        IERC20All(debtTokens[borrowAsset][lenderId]).approveDelegation(
            address(brokerProxyAddress), //
            borrowAmount
        );

        bytes memory data = abi.encodePacked(
            uint8(0x11), // 1
            uint16(56), // redundant, 2
            borrowAsset, // 20
            user, // 20
            populateAmountBorrow(lenderId, DEAULT_MODE, borrowAmount) // 16
        );

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }
}
