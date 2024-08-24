// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

contract ComposerTestTaiko is DeltaSetup {
    uint8 RITSU = 150;
    address internal constant USDC_WETH_RITSU_POOL = 0xeF4a016F3E54c4520220adE7a496842ECbF83E09;

    function test_taiko_composer_ritsu_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.3e18;

        address assetIn = USDC;
        address assetOut = WETH;
        deal(assetIn, user, 1e23);

        bytes memory dataRitsu = getSpotExactInSingleGen2(
            assetIn,
            assetOut,
            RITSU,
            uint16(DEX_FEE_LOW) //
        );

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
        console.log("gas", gas, WETH);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 0.7369 WETH
        assertApproxEqAbs(736925511614964287, received, 1);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, uint16 fee) internal view returns (bytes memory data) {
        address pool = USDC_WETH_RITSU_POOL;
        uint8 action = 0;
        console.log("pool", pool, poolId);
        return abi.encodePacked(tokenIn, action, poolId, pool, uint24(fee), tokenOut);
    }
}

// Ran 11 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_taiko_composer_borrow() (gas: 917038)
// Logs:
//   gas 378730
//   gas 432645

// [PASS] test_taiko_composer_depo() (gas: 371016)
// Logs:
//   gas 248957

// [PASS] test_taiko_composer_multi_route_exact_in() (gas: 377134)
// Logs:
//   gas 192095

// [PASS] test_taiko_composer_multi_route_exact_in_native() (gas: 368206)
// Logs:
//   gas 374361

// [PASS] test_taiko_composer_multi_route_exact_in_native_out() (gas: 633199)
// Logs:
//   gas-exactIn-native-out-2 split 547586

// [PASS] test_taiko_composer_multi_route_exact_in_self() (gas: 399348)
// Logs:
//   gas 219240

// [PASS] test_taiko_composer_multi_route_exact_out() (gas: 390674)
// Logs:
//   gas 190957

// [PASS] test_taiko_composer_multi_route_exact_out_native_in() (gas: 408213)
// Logs:
//   gas-exactOut-native-in-2 split 385726

// [PASS] test_taiko_composer_multi_route_exact_out_native_out() (gas: 558685)
// Logs:
//   gas-exactOut-native-out-2 split 413439

// [PASS] test_taiko_composer_repay() (gas: 985744)
// Logs:
//   gas 378730
//   gas 432646
//   gas 102301

// [PASS] test_taiko_composer_withdraw() (gas: 702003)
// Logs:
//   gas 378730
//   gas 253948

// Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 319.97ms (40.41ms CPU time)
