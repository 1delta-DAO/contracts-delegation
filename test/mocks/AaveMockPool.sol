// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AaveMockPool {
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external {
        bool success = IAaveFlashLoanReceiver(receiverAddress).executeOperation(asset, amount, amount * 5 / 10000, msg.sender, params);

        require(success, "Callback failed");
    }
}

interface IAaveFlashLoanReceiver {
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params) external returns (bool);
}

interface IAavePool {
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external;
}
