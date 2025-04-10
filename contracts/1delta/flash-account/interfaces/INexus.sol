// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionMode} from "../utils/ModeLib.sol";

interface INexus {
    function executeFromExecutor(ExecutionMode mode, bytes calldata executionCalldata)
        external
        payable
        returns (bytes[] memory returnData);
}
