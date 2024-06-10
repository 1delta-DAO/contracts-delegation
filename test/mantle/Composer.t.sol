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

    function transferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(0x15),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function wrap(uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(0x19),
            uint112(amount) //
        ); // 14 bytes
    }

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

        bytes memory transfer = transferIn(
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

        bytes memory transfer = transferIn(
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

        bytes memory dataAgni = getSpotExactInSingleGen2(assetIn, assetOut, AGNI, uint16(DEX_FEE_STABLES));
        bytes memory dataFusion = getSpotExactInSingleGen2(assetIn, assetOut, FUSION_X, uint16(DEX_FEE_STABLES));

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

    function getNativeToWeth()
        internal
        view
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = WMNT;
        tks[1] = METH;
        tks[2] = WETH;
        fees = new uint16[](2);
        fees[0] = uint16(250);
        fees[1] = uint16(DEX_FEE_STABLES);
        pids = new uint8[](2);
        pids[0] = CLEOPATRA_CL;
        pids[1] = AGNI;
    }

    function test_mantle_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMin = 0.0e18;

        address assetIn = WMNT;
        address assetOut = WETH;
        vm.deal(user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2Self(assetIn, assetOut, AGNI, uint16(DEX_FEE_LOW));
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToWeth();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees, false);
        }
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

        data = abi.encodePacked(wrap(amount), data);
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: amount}(data);
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

        bytes memory dataAgni = getSpotExactInSingleGen2Self(assetIn, assetOut, AGNI, uint16(DEX_FEE_STABLES));
        bytes memory dataFusion = getSpotExactInSingleGen2Self(assetIn, assetOut, FUSION_X, uint16(DEX_FEE_STABLES));

        bytes memory transfer = transferIn(
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

        bytes memory dataAgni = getSpotExactOutSingleGen2(assetIn, assetOut, AGNI, uint16(DEX_FEE_STABLES));
        bytes memory dataFusion = getSpotExactOutSingleGen2(assetIn, assetOut, FUSION_X, uint16(DEX_FEE_STABLES));

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

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(10), poolId, pool, fee, tokenOut);
    }

    function getSpotExactInMultiGen2(
        address[] memory tokens,
        uint8[] memory pids,
        uint16[] memory fees,
        bool self
    ) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        if (self) actions[0] = 10;
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return data;
    }

    function getSpotExactInSingleGen2Self(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        return abi.encodePacked(tokenIn, uint8(0), poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        return abi.encodePacked(tokenOut, uint8(11), poolId, pool, fee, tokenIn);
    }

    function _deposit(address asset, address user, uint256 amount, uint8 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
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

// Ran 7 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_mantle_composer_borrow() (gas: 917049)
// Logs:
//   gas 378807
//   gas 432642

// [PASS] test_mantle_composer_depo() (gas: 371051)
// Logs:
//   gas 249034

// [PASS] test_mantle_composer_multi_route_exact_in() (gas: 377161)
// Logs:
//   gas 192081

// [PASS] test_mantle_composer_multi_route_exact_in_self() (gas: 399292)
// Logs:
//   gas 219302

// [PASS] test_mantle_composer_multi_route_exact_out() (gas: 390341)
// Logs:
//   gas 190953

// [PASS] test_mantle_composer_repay() (gas: 985895)
// Logs:
//   gas 378807
//   gas 432642
//   gas 102377

// [PASS] test_mantle_composer_withdraw() (gas: 702011)
// Logs:
//   gas 378807
//   gas 253947

// Suite result: ok. 7 passed; 0 failed; 0 skipped; finished in 163.74ms (20.60ms CPU time)
