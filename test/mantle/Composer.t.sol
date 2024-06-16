// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/deploy/mantle/composable/Commands.sol";
import "./ComposerUtils.sol";
import "./DeltaSetup.f.sol";

contract ComposerTest is DeltaSetup, ComposerUtils {

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
            uint8(Commands.REPAY), // 1
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
            uint8(Commands.WITHDRAW), // 1
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
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            encodeExactInParams(amount / 2, amountMin, false),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_IN),
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
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToWeth();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            encodeExactInParams(amount / 2, amountMin, true),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_IN),
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
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getNativeToWeth();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            encodeExactOutParams(amount / 2, amountMax / 2, false),
            brokerProxyAddress,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_OUT),
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
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToNative();
            dataFusion = getSpotExactOutMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            encodeExactOutParams(amount / 2, amountMax / 2, true),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_OUT),
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
            uint16(DEX_FEE_LOW) //
        );
        bytes memory dataFusion;
        {
            (
                address[] memory tks,
                uint8[] memory pids, //
                uint16[] memory fees
            ) = getWethToNative();
            dataFusion = getSpotExactInMultiGen2(tks, pids, fees);
        }
        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            encodeExactInParams(amount / 2, 0, false),
            brokerProxyAddress,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_IN),
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
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory transfer = transferIn(
            assetIn,
            brokerProxyAddress,
            amount //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            encodeExactInParams(amount / 2, amountMin, true),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_IN),
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
            uint16(DEX_FEE_STABLES) //
        );
        bytes memory dataFusion = getSpotExactOutSingleGen2(
            assetIn,
            assetOut,
            FUSION_X,
            uint16(DEX_FEE_STABLES) //
        );

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_OUT),
            encodeExactOutParams(amount / 2, maxIn, false),
            user,
            uint16(dataAgni.length), // begin agni data
            dataAgni,
            uint8(Commands.SWAP_EXACT_OUT),
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
        uint16[] memory fees
    ) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(
                data,
                actions[i], // action id
                pids[i], // dex identifier
                pool, // dex param 0
                fees[i], // dex param 1
                tokens[i + 1]
            );
        }
        return data;
    }

    function getSpotExactOutMultiGen2(
        address[] memory tokens,
        uint8[] memory pids,
        uint16[] memory fees
    ) internal view returns (bytes memory data) {
        uint8[] memory actions = new uint8[](pids.length);
        data = abi.encodePacked(tokens[0]);
        for (uint i; i < pids.length; i++) {
            actions[i] = 0;
            address pool = testQuoter._v3TypePool(tokens[i], tokens[i + 1], fees[i], pids[i]);
            data = abi.encodePacked(data, actions[i], pids[i], pool, fees[i], tokens[i + 1]);
        }
        return abi.encodePacked(data, uint8(99));
    }

    function getSpotExactInSingleGen2(
        address tokenIn,
        address tokenOut,
        uint8 poolId,
        uint16 fee
    ) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenIn, tokenOut, fee, poolId);
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, fee, tokenOut);
    }

    function getSpotExactOutSingleGen2(
        address tokenIn,
        address tokenOut,
        uint8 poolId,
        uint16 fee
    ) internal view returns (bytes memory data) {
        address pool = testQuoter._v3TypePool(tokenOut, tokenIn, fee, poolId);
        uint8 action = 0;
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
            uint8(Commands.DEPOSIT),
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
            uint8(Commands.BORROW),
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

// Ran 11 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_mantle_composer_borrow() (gas: 917038)
// Logs:
//   gas 378730
//   gas 432645

// [PASS] test_mantle_composer_depo() (gas: 371016)
// Logs:
//   gas 248957

// [PASS] test_mantle_composer_multi_route_exact_in() (gas: 377134)
// Logs:
//   gas 192095

// [PASS] test_mantle_composer_multi_route_exact_in_native() (gas: 368206)
// Logs:
//   gas 374361

// [PASS] test_mantle_composer_multi_route_exact_in_native_out() (gas: 633199)
// Logs:
//   gas-exactIn-native-out-2 split 547586

// [PASS] test_mantle_composer_multi_route_exact_in_self() (gas: 399348)
// Logs:
//   gas 219240

// [PASS] test_mantle_composer_multi_route_exact_out() (gas: 390674)
// Logs:
//   gas 190957

// [PASS] test_mantle_composer_multi_route_exact_out_native_in() (gas: 408213)
// Logs:
//   gas-exactOut-native-in-2 split 385726

// [PASS] test_mantle_composer_multi_route_exact_out_native_out() (gas: 558685)
// Logs:
//   gas-exactOut-native-out-2 split 413439

// [PASS] test_mantle_composer_repay() (gas: 985744)
// Logs:
//   gas 378730
//   gas 432646
//   gas 102301

// [PASS] test_mantle_composer_withdraw() (gas: 702003)
// Logs:
//   gas 378730
//   gas 253948

// Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 319.97ms (40.41ms CPU time)
