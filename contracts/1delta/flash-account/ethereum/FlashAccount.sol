// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "../FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
contract FlashAccount is FlashAccountBase {
    // Aave V3 pool ethereum mainnet
    address internal constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // Morpho pool
    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // Balancer V2 vault
    address internal constant BALANCER_V2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /**
     * @dev Explicit flash loan callback functions
     * All of them are locked through the execution lock to prevent access outside
     * of the `execute` functions
     */

    /**
     * Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        require(msg.sender == AAVE_V3, "Invalid sender");

        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * Balancer flash loan
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        require(msg.sender == BALANCER_V2, "Invalid sender");
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        require(msg.sender == MORPHO, "Invalid sender");
        // execute furhter operations
        _decodeAndExecute(params);
    }
}
