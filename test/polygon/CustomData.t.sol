// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "../shared/interfaces/ICurvePool.sol";
import "./DeltaSetup.f.sol";

contract CustomDataTestPolygon is DeltaSetup {
    function test_polygon_custom_open() external {
        uint16 lenderId = 0;
        address user = testUser;

        uint256 amount = 500.0e18;
        address asset = TokensPolygon.WMATIC;

        address borrowAsset = TokensPolygon.USDC;

        _deposit(asset, user, amount, lenderId);

        uint256 openAmount = 2.00e6;

        approveBorrowDelegation(user, borrowAsset, openAmount, lenderId);

        vm.expectRevert();
        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(getOpenUsdcMatic());
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function _deposit(address asset, address user, uint256 amount, uint16 lenderId) internal {
        deal(asset, user, amount);

        vm.prank(user);
        IERC20All(asset).approve(address(brokerProxyAddress), amount);

        bytes memory transfer = transferIn(
            asset,
            brokerProxyAddress,
            amount //
        );
        bytes memory data = deposit(
            asset,
            user,
            amount,
            lenderId //
        );
        data = abi.encodePacked(transfer, data);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function getOpenUsdcMatic() internal pure returns (bytes memory data) {
        data = hex"020000000000000000025be22d8f2954cb00000000000000000000000186a000422791bca1f2de4661ed88a30c99a7a9449aa841740364fc4912b5440d628d2337a16363d16a5e3a9cba0426f20d500b1d8e8ef31e21c99d1db9a6444d3adf127000020200000000000000000e1b717a153d3d3e00000000000000000000000927c0006e2791bca1f2de4661ed88a30c99a7a9449aa8417403024646e8a5e1d14e2da01577822d6346c7883c689000648f3cf7ad23cd3cadbd9735aff958023239c6a06300036baead5db7fee6d5c9f0ca07bb5038c4cd279f5c36630d500b1d8e8ef31e21c99d1db9a6444d3adf127000020200000000000000000e25fb88623627e200000000000000000000000927c000982791bca1f2de4661ed88a30c99a7a9449aa841740368273c39ebd4e0c49f8cc6e5a2b3c0e4ca355b535226f87ceb23fd6bc0add59e62ac25578270cff1b9f6190068bbbd54c1cd649288d2e584917778eeccd8d8254d26f81bfd67037b42cf73acf2047067bd4f2c47d9bfd60096ed9e3f98bbed560e66b89aac922e29d4596a96420d500b1d8e8ef31e21c99d1db9a6444d3adf127000020200000000000000000712acccabed0b1400000000000000000000000493e000422791bca1f2de4661ed88a30c99a7a9449aa841740302934f3f8749164111f0386ece4f4965a687e576d500640d500b1d8e8ef31e21c99d1db9a6444d3adf1270000202000000000000000004b84ed22727259f0000000000000000000000030d40006e2791bca1f2de4661ed88a30c99a7a9449aa8417403005645dcb64c059aa11212707fbf4e7f984440a8cf00648f3cf7ad23cd3cadbd9735aff958023239c6a06300000f663c16dd7c65cf87edb9229464ca77aeea536b01f40d500b1d8e8ef31e21c99d1db9a6444d3adf12700002020000000000000000025a6538bfe8fa4b00000000000000000000000186a0006e2791bca1f2de4661ed88a30c99a7a9449aa8417403005f69c2ec01c22843f8273838d570243fd196301401f48f3cf7ad23cd3cadbd9735aff958023239c6a06300007a7374873de28b06386013da94cbd9b554f6ac6e00640d500b1d8e8ef31e21c99d1db9a6444d3adf12700002020000000000000000025aa285581ca75000000000000000000000000186a0006e2791bca1f2de4661ed88a30c99a7a9449aa841740303e7e0eb9f6bcccfe847fdf62a3628319a092f11a22d928f3cf7ad23cd3cadbd9735aff958023239c6a063000058359563b3f4854428b1b98e91a42471e6d20b8e27100d500b1d8e8ef31e21c99d1db9a6444d3adf12700002";
    }
}

// Ran 11 tests for test/mantle/Composer.t.sol:ComposerTest
// [PASS] test_polygon_composer_borrow() (gas: 917038)
// Logs:
//   gas 378730
//   gas 432645

// [PASS] test_polygon_composer_depo() (gas: 371016)
// Logs:
//   gas 248957

// [PASS] test_polygon_composer_multi_route_exact_in() (gas: 377134)
// Logs:
//   gas 192095

// [PASS] test_polygon_composer_multi_route_exact_in_native() (gas: 368206)
// Logs:
//   gas 374361

// [PASS] test_polygon_composer_multi_route_exact_in_native_out() (gas: 633199)
// Logs:
//   gas-exactIn-native-out-2 split 547586

// [PASS] test_polygon_composer_multi_route_exact_in_self() (gas: 399348)
// Logs:
//   gas 219240

// [PASS] test_polygon_composer_multi_route_exact_out() (gas: 390674)
// Logs:
//   gas 190957

// [PASS] test_polygon_composer_multi_route_exact_out_native_in() (gas: 408213)
// Logs:
//   gas-exactOut-native-in-2 split 385726

// [PASS] test_polygon_composer_multi_route_exact_out_native_out() (gas: 558685)
// Logs:
//   gas-exactOut-native-out-2 split 413439

// [PASS] test_polygon_composer_repay() (gas: 985744)
// Logs:
//   gas 378730
//   gas 432646
//   gas 102301

// [PASS] test_polygon_composer_withdraw() (gas: 702003)
// Logs:
//   gas 378730
//   gas 253948

// Suite result: ok. 11 passed; 0 failed; 0 skipped; finished in 319.97ms (40.41ms CPU time)
