// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract GasZipMock {
    constructor(uint256 destinationChains, bytes32 to, uint256 amount) {
        expectedDestinationChains = destinationChains;
        expectedTo = to;
        expectedAmount = amount;
    }

    uint256 public expectedDestinationChains;
    bytes32 public expectedTo;
    uint256 public expectedAmount;

    function deposit(uint256 destinationChains, bytes32 to) external payable {
        if (destinationChains != expectedDestinationChains) {
            console.log("Invalid destination chain", destinationChains);
            revert("Invalid destination chain");
        }
        if (to != expectedTo) {
            revert("Invalid receiver");
        }
        if (msg.value != expectedAmount) {
            revert("Invalid amount");
        }
    }
}

