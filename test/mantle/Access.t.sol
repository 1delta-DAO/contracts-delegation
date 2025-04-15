// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract AccessTests is DeltaSetup {
    address internal attacker = 0x0c38845C2587e2fb0b7fba1cfB27f260F74066Aa;

    function test_mantle_flash_loan_operation_gatekeep() external {
        address user = testUser;
        vm.assume(user != address(0));

        // define some valid flash loan params
        address asset = TokensMantle.WMNT;
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
        vm.expectRevert(bytes4(0xbafe1c53)); // ("InvalidFlashLoan()");
        vm.prank(attacker);
        IFlashAggregator(brokerProxyAddress).executeOperation(assets, amounts, modes, brokerProxyAddress, params);

        // attack from lending pool
        vm.expectRevert(bytes4(0x48f5c3ed)); // ("InvalidCaller()");
        vm.prank(attacker);
        ILendingPool(LendleMantle.POOL).flashLoan(
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
        uint256 amount0 = 21233;
        uint256 amount1 = 2112324324432;

        // some data
        bytes memory data = abi.encodePacked(TokensMantle.WMNT);
        // direct
        vm.expectRevert(bytes4(0xb2c02722)); // ("BadPool()");
        vm.prank(attacker);
        IFlashAggregator(brokerProxyAddress).hook(brokerProxyAddress, amount0, amount1, data);

        address pool = testQuoter.v2TypePairAddress(TokensMantle.aUSD, TokensMantle.USDC, DexMappingsMantle.CLEO_V1_STABLE);

        // should error before any data is decoded
        vm.expectRevert(bytes4(0xbafe1c53)); // ("InvalidFlashLoan()");
        vm.prank(attacker);
        IERC20All(pool).swap(
            amount0,
            amount1,
            brokerProxyAddress,
            abi.encodePacked(TokensMantle.aUSD, uint8(0), DexMappingsMantle.CLEO_V1_STABLE, pool, uint16(0), TokensMantle.USDC) // the data here makes the `badPool` check pass
        );
    }
}
