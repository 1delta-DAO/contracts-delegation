// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBrokerProxy {
    function multicall(bytes[] calldata data) external payable;
}
