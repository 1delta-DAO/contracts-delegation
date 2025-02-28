// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "../FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
contract FlashAccount is FlashAccountBase {
    // Aave V3 pool ethereum mainnet
    address internal constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

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
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }
}
