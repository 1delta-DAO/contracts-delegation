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

    function unwrap(address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(0x20),
            receiver,
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

    function encodeExactOutParams(uint256 amountOut, uint256 maximumAmountIn, bool paySelf) internal pure returns (uint256) {
        uint256 am = uint128(amountOut);
        am = (am & ~UINT128_MASK_UPPER) | (uint256(maximumAmountIn) << 128);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
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

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_STABLES),
            false //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES),
            false //
        );

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

    function getWethToNative()
        internal
        view
        returns (
            address[] memory tks,
            uint8[] memory pids, //
            uint16[] memory fees
        )
    {
        tks = new address[](3);
        tks[0] = WETH;
        tks[1] = METH;
        tks[2] = WMNT;
        fees = new uint16[](2);
        fees[0] = uint16(DEX_FEE_STABLES);
        fees[1] = uint16(250);
        pids = new uint8[](2);
        pids[0] = AGNI;
        pids[1] = CLEOPATRA_CL;
    }

    function test_mantle_composer_multi_route_exact_in_native() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMin = 0.10e18;

        address assetIn = WMNT;
        address assetOut = WETH;
        vm.deal(user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_LOW),
            true //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToWeth();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees, true);
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

    function test_mantle_composer_multi_route_exact_out_native_out() external {
        address user = testUser;
        uint256 amount = 4000.0e18;
        uint256 amountMax = 5.0e18;

        address assetIn = WETH;
        address assetOut = WMNT;
        deal(assetIn, user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_LOW), //
            false
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToWeth();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees, false);
        }
        bytes memory data = abi.encodePacked(
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, amountMax / 2, false),
            brokerProxyAddress,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, amountMax / 2, false),
            brokerProxyAddress,
            uint16(dataFusion.length), // begin fusionX data
            dataFusion
        );

        data = abi.encodePacked(data, unwrap(user, amount));

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountMax);

        uint balanceOutBefore = user.balance;
        uint balanceInBefore = IERC20All(assetIn).balanceOf(user);
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-exactOut-native-out-2 split", gas);
        }
        uint balanceOutAfter = user.balance;
        uint balanceInAfter = IERC20All(assetIn).balanceOf(user);

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, amount, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 1668753875334069967, 0);
    }

    function test_mantle_composer_multi_route_exact_out_native_in() external {
        address user = testUser;
        uint256 amount = 2.0e18;
        uint256 amountMax = 9000.0e18;

        address assetIn = WMNT;
        address assetOut = WETH;
        vm.deal(user, amountMax);

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_LOW), //
            true
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToNative();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees, true);
        }
        bytes memory data = abi.encodePacked(
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, amountMax / 2, true),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, amountMax / 2, true),
            user,
            uint16(dataFusion.length), // begin fusionX data
            dataFusion
        );

        data = abi.encodePacked(wrap(amountMax), data, unwrap(user, 0));

        uint balanceOutBefore = IERC20All(assetOut).balanceOf(user);
        uint balanceInBefore = user.balance;
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose{value: amountMax}(data);
            gas = gas - gasleft();
            console.log("gas-exactOut-native-in-2 split", gas);
        }
        uint balanceOutAfter = IERC20All(assetOut).balanceOf(user);
        uint balanceInAfter = user.balance;

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, amount, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, 4825933262798723917376, 0);
    }

    function test_mantle_composer_multi_route_exact_in_native_out() external {
        address user = testUser;
        uint256 amount = 2.0e18;
        uint256 amountMin = 4000.0e18;

        address assetIn = WETH;
        address assetOut = WMNT;
        deal(assetIn, user, amount);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_LOW),
            false //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToNative();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees, false);
        }
        bytes memory data = abi.encodePacked(
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, 0, false),
            brokerProxyAddress,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_IN,
            encodeExactInParams(amount / 2, 0, false),
            brokerProxyAddress,
            uint16(dataFusion.length), // begin fusionX data
            dataFusion
        );

        data = abi.encodePacked(data, unwrap(user, amountMin));

        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amount);

        uint balanceOutBefore = user.balance;
        uint balanceInBefore = IERC20All(assetIn).balanceOf(user);
        {
            vm.prank(user);
            uint gas = gasleft();
            IFlashAggregator(brokerProxyAddress).deltaCompose(data);
            gas = gas - gasleft();
            console.log("gas-exactIn-native-out-2 split", gas);
        }
        uint balanceOutAfter = user.balance;
        uint balanceInAfter = IERC20All(assetIn).balanceOf(user);

        assertApproxEqAbs(balanceOutAfter - balanceOutBefore, 4791714389649651447685, 1);
        assertApproxEqAbs(balanceInBefore - balanceInAfter, amount, 0);
    }

    function test_mantle_composer_multi_route_exact_in_self() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 900.0e6;

        address assetIn = USDC;
        address assetOut = USDT;
        deal(assetIn, user, 1e23);

        bytes memory dataAgni = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_STABLES),
            true //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES),
            true //
        );

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

        bytes memory dataAgni = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            AGNI,
            uint16(DEX_FEE_STABLES),
            false //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES),
            false //
        );

        bytes memory data = abi.encodePacked(
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, maxIn, false),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            SWAP_EXACT_OUT,
            encodeExactOutParams(amount / 2, maxIn, false),
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

    function getSpotExactInMultiGen2(
        address[] memory tokens,
        uint8[] memory pids,
        uint16[] memory fees,
        bool self
    ) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        if (!self) actions[0] = 10;
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return data;
    }

    function getSpotExactOutMultiGen2(
        address[] memory tokens,
        uint8[] memory pids,
        uint16[] memory fees,
        bool self
    ) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            actions[i] = 1;
            if (!self && i == (pids.length - 1)) actions[i] = 11;
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return abi.encodePacked(data, uint8(99));
    }

    function getSpotExactInSingleGen2(
        address tokenIn,
        address tokenOut,
        uint8 poolId,
        uint16 fee,
        bool self
    ) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        if (!self) action = 10;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(
        address tokenIn,
        address tokenOut,
        uint8 poolId,
        uint16 fee,
        bool self
    ) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        uint8 action = 1;
        if (!self) action = 11;
        return abi.encodePacked(tokenOut, action, poolId, pool, fee, tokenIn, uint8(99));
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

// Ran 9 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_mantle_composer_borrow() (gas: 916996)
// Logs:
//   gas 378726
//   gas 432641

// [PASS] test_mantle_composer_depo() (gas: 370985)
// Logs:
//   gas 248953

// [PASS] test_mantle_composer_multi_route_exact_in() (gas: 377195)
// Logs:
//   gas 192081

// [PASS] test_mantle_composer_multi_route_exact_in_native() (gas: 368278)
// Logs:
//   gas 374362

// [PASS] test_mantle_composer_multi_route_exact_in_native_out() (gas: 633219)
// Logs:
//   gas-exactIn-native-out-2 split 547587

// [PASS] test_mantle_composer_multi_route_exact_in_self() (gas: 399399)
// Logs:
//   gas 219226

// [PASS] test_mantle_composer_multi_route_exact_out() (gas: 390492)
// Logs:
//   gas 190951

// [PASS] test_mantle_composer_repay() (gas: 985698)
// Logs:
//   gas 378726
//   gas 432642
//   gas 102297

// [PASS] test_mantle_composer_withdraw() (gas: 701987)
// Logs:
//   gas 378726
//   gas 253944

// Suite result: ok. 9 passed; 0 failed; 0 skipped; finished in 147.99ms (22.59ms CPU time)
