// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBeacon {
    function implementation() external view returns (address result);

    function owner() external view returns (address result);
}
