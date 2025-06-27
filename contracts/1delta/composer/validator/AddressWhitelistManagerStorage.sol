// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

abstract contract AddressWhitelistManagerStorage is Initializable {
    address public owner;

    mapping(address => bool) public whitelistedAaveV2Pools;
    mapping(address => bool) public whitelistedAaveV3Pools;
    mapping(address => bool) public whitelistedCompoundV3Comets;
    mapping(address => bool) public whitelistedCompoundV2CTokens;
    mapping(address => bool) public whitelistedMorphos;

    uint256[45] private __gap;
}
