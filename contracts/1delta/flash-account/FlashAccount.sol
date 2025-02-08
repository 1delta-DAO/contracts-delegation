// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {LightAccount} from "./LightAccount.sol";
import {IEntryPoint} from "./account-abstraction/interfaces/IEntryPoint.sol";

contract FlashAccount is LightAccount {

    constructor(IEntryPoint entryPoint_) LightAccount(entryPoint_) {}

    /** Aave simple flash loan */
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

    /** Balancer flash loan */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    function _decodeAndExecute(bytes calldata params) internal {
        (
            address[] memory dest, //
            uint256[] memory value,
            bytes[] memory func
        ) = abi.decode(params, (address[], uint256[], bytes[]));
        if (dest.length != func.length || dest.length != value.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }
}
