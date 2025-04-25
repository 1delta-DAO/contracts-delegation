// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IK1ValidatorFactory {
    function createAccount(address eoaOwner, uint256 index, address[] calldata attesters, uint8 threshold)
        external
        payable
        returns (address payable);
}
