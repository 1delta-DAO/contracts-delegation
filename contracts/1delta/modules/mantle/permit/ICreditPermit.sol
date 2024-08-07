// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICreditPermit {
    function delegationWithSig(
        address delegator,
        address delegatee,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
