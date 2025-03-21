// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Lib.sol";

interface IChainBase {
    function getRpcUrl() external view returns (string memory);

    function getForkBlock() external view returns (uint256);

    function getTokenAddress(string memory tokenName) external view returns (address);
}

abstract contract ChainBase is IChainBase {
    address internal constant NOT_AVAILABLE = address(uint160(uint256(keccak256("NOT_AVAILABLE"))));

    mapping(uint256 chainId => mapping(string tokenName => address tokenAddress)) internal tokens;
    uint256 public immutable CHAIN_ID;

    constructor(uint256 chainId) {
        CHAIN_ID = chainId;
    }

    function getRpcUrl() public view virtual returns (string memory);

    function getForkBlock() public view virtual returns (uint256);

    function getTokenAddress(string memory tokenName) public view virtual returns (address) {
        address t = tokens[CHAIN_ID][tokenName];
        return t == address(0) ? NOT_AVAILABLE : t;
    }
}
