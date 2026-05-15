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
        _invokeCallback(receiverAddress, assets, amounts, params);
    }

    /// @notice Phiat-style slimmer signature: no modes / onBehalfOf
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params,
        uint16 referralCode
    )
        external
    {
        _invokeCallback(receiverAddress, assets, amounts, params);
    }

    function _invokeCallback(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    )
        private
    {
        address[] memory tempAssets = new address[](assets.length);
        uint256[] memory tempAmounts = new uint256[](assets.length);
        uint256[] memory tempFees = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            tempAssets[i] = assets[i];
            tempAmounts[i] = amounts[i];
            tempFees[i] = amounts[i] * 9 / 10000; // 0.09% fee
        }

        bool success =
            IAaveV2FlashLoanReceiver(receiverAddress).executeOperation(tempAssets, tempAmounts, tempFees, msg.sender, params);

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
