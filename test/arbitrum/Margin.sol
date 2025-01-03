// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract MarginTestArbitrum is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function test_arbitrum_open_exact_in() external {
        uint16 lenderId = VENUS;
        address user = testUser;
        uint256 amount = 200.0e6;
        uint256 amountMin = 190.0e6;

        address assetIn = TokensArbitrum.USDC;
        address assetOut = TokensArbitrum.USDT;
        deal(assetIn, user, amount);

        _deposit(assetOut, user, amount, lenderId);

        bytes memory swapData = getOpenExactInSingle(
            assetIn,
            assetOut,
            lenderId //
        );

        bytes memory data = encodeFlashSwap(
            Commands.FLASH_SWAP_EXACT_IN,
            amount,
            amountMin,
            false,
            swapData //
        );

        approveBorrowDelegation(user, assetIn, amount, lenderId);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);
    }
}
