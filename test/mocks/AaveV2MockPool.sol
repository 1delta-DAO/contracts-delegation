// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract AaveV2MockPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    )
        external
    {
        // Simple mock implementation that just calls the callback
        address[] memory tempAssets = new address[](assets.length);
        uint256[] memory tempAmounts = new uint256[](assets.length);
        uint256[] memory tempFees = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            tempAssets[i] = assets[i];
            tempAmounts[i] = amounts[i];
            tempFees[i] = amounts[i] * 9 / 10000; // 0.09% fee for Aave V2
        }

        bool success = IAaveV2FlashLoanReceiver(receiverAddress).executeOperation(tempAssets, tempAmounts, tempFees, msg.sender, params);

        require(success, "Callback failed");
    }
}

interface IAaveV2FlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);
}

interface IAaveV2Pool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    )
        external;
}
