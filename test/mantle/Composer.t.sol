// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract SwapGen2Test is DeltaSetup {
    function test_composer() external {
        bytes memory data = abi.encodePacked(uint8(0), uint16(20), uint8(1), USDT, uint16(32), uint8(2), uint256(1));
        uint gas = gasleft();
        // composer.deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

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
}
