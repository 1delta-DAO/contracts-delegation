// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract AccessTests is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    address internal attacker = 0x0c38845C2587e2fb0b7fba1cfB27f260F74066Aa;

    function test_mantle_flash_loan_operation_gatekeep() external {
        address user = testUser;
        vm.assume(user != address(0));

        // define some valid flash loan params
        address asset = WMNT;
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256[] memory amounts = new uint256[](1);
        uint256 amount = 11111111111111111;
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory withdrawFromVictim = withdraw(asset, attacker, amount, 0);
        bytes memory params = abi.encodePacked(
            uint8(0), // Lendle
            user, // try impersonate
            withdrawFromVictim // operation
        );

        // attack directly
        vm.expectRevert(0xbafe1c53); // ("InvalidFlashLoan()");
        vm.prank(attacker);
        IFlashAggregator(brokerProxyAddress).executeOperation(assets, amounts, modes, brokerProxyAddress, params);

        // attack from lending pool
        vm.expectRevert(0x48f5c3ed); // ("InvalidCaller()");
        vm.prank(attacker);
        ILendingPool(LENDLE_POOL).flashLoan(
            brokerProxyAddress,
            assets,
            amounts,
            modes,
            brokerProxyAddress, // self
            params,
            0
        );
    }

    function test_mantle_v2_gatekeep() external {
        uint amount0 = 21233;
        uint amount1 = 2112324324432;

        // some data
        bytes memory data = abi.encodePacked(WMNT);
        // direct
        vm.expectRevert(0xb2c02722); // ("BadPool()");
        vm.prank(attacker);
        IFlashAggregator(brokerProxyAddress).hook(brokerProxyAddress, amount0, amount1, data);

        address pool = testQuoter._v2TypePairAddress(aUSD, USDC, CLEO_V1_STABLE);

        // should error before any data is decoded
        vm.expectRevert(0xbafe1c53); // ("InvalidFlashLoan()");
        vm.prank(attacker);
        IERC20All(pool).swap(
            amount0,
            amount1,
            brokerProxyAddress,
            abi.encodePacked(aUSD,uint8(0), CLEO_V1_STABLE, pool, uint16(0), USDC) // the data here makes the `badPool` check pass
        );
    }
}
