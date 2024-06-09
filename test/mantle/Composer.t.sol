// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ComposerTest is DeltaSetup {
    uint8 DEAULT_MODE = 2;
    uint8 SWAP_EXACT_IN = 0x0;
    uint8 SWAP_EXACT_OUT = 1;
    uint256 private constant USE_PERMIT2_FLAG = 1 << 127;
    // uint256 private constant UNWRAP_NATIVE_MASK = 1 << 254;
    // uint256 private constant PAY_SELF = 1 << 254;
    uint256 private constant PAY_SELF = 1 << 255;
    uint256 private constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    uint256 private constant UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;
    uint256 private constant LENDER_ID_MASK = 0x0000000000000000000000000000000000ff0000000000000000000000000000;
    uint256 private constant UINT128_MASK_UPPER = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;

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

    function encodeExactOutParams(uint256 amountOut, uint256 maximumAmountIn) internal pure returns (uint256) {
        uint256 am = uint128(amountOut);
        am = (am & ~UINT128_MASK_UPPER) | (uint256(maximumAmountIn) << 128);
        return am;
    }

    function encodeExactInParams(uint256 amountIn, uint256 minimumOut, bool paySelf) internal pure returns (uint256) {
        uint256 am = uint128(amountIn);
        am = (am & ~UINT128_MASK_UPPER) | (uint256(minimumOut) << 128);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
        return am;
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
            USDT,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = abi.encodePacked(
            uint8(0x13), // 1
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
            borrowAsset,
            brokerProxyAddress,
            repayAmount //
        );

        bytes memory data = abi.encodePacked(
            uint8(0x18), // 1
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
            asset, // 20
            user, // 20
            populateAmountWithdraw(lenderId, withdrawAmount) // 15
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
        uint256 amountMin = 900.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(assetIn, assetOut, AGNI);
        bytes memory dataFusion = getSpotExactInSingleGen2(assetIn, assetOut, FUSION_X);

        bytes memory data = abi.encodePacked(
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, amountMin, false),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, amountMin, false),
            user,
            uint16(dataFusion.length), // begin fusionX data
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

    function test_mantle_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2Self(assetIn, assetOut, AGNI);
        bytes memory dataFusion = getSpotExactInSingleGen2Self(assetIn, assetOut, FUSION_X);

        bytes memory transfer = abi.encodePacked(
            uint8(0x15),
            assetIn,
            brokerProxyAddress,
            amount //
        );

        bytes memory data = abi.encodePacked(
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, amountMin, true),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, amountMin, true),
            user,
            uint16(dataFusion.length), // begin fusionX data
            dataFusion
        );

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amount);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(abi.encodePacked(transfer, data));
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_mantle_composer_multi_route_exact_out() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 maxIn = 1040.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactOutSingleGen2(assetIn, assetOut, AGNI);
        bytes memory dataFusion = getSpotExactOutSingleGen2(assetIn, assetOut, FUSION_X);

        bytes memory data = abi.encodePacked(
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, maxIn),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, maxIn),
            user,
            uint16(dataFusion.length), // begin fusionX data
            dataFusion
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), maxIn * 2);

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

    function getSpotExactInSingleGen2Self(address tokenIn, address tokenOut, uint8 poolId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(address tokenIn, address tokenOut, uint8 poolId) internal view returns (bytes memory data) {
        uint16 fee = uint16(DEX_FEE_STABLES);
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenOut, uint8(11), poolId, pool, fee, tokenIn);
    }

    function _deposit(address asset, address user, uint256 amount, uint8 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = abi.encodePacked(
            uint8(0x15),
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = abi.encodePacked(
            uint8(0x13), // 1
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

// Ran 5 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_mantle_composer_borrow() (gas: 917234)
// Logs:
//   gas 378856
//   gas 432689

// [PASS] test_mantle_composer_depo() (gas: 371166)
// Logs:
//   gas 249083

// [PASS] test_mantle_composer_multi_route_exact_in() (gas: 380612)
// Logs:
//   gas 196757

// [PASS] test_mantle_composer_repay() (gas: 986219)
// Logs:
//   gas 378856
//   gas 432689
//   gas 102425

// [PASS] test_mantle_composer_withdraw() (gas: 702160)
// Logs:
//   gas 378856
//   gas 253987

// Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 171.55ms (16.04ms CPU time)
