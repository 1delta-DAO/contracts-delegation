// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Lib.sol";

interface IChainBase {
    struct AaveTokens {
        address aToken;
        address vToken;
        address sToken;
    }

    function getRpcUrl() external view returns (string memory);

    function getForkBlock() external view returns (uint256);

    function getTokenAddress(string memory tokenName) external view returns (address);

    function getAaveV3LendingTokens(address token) external view returns (AaveTokens memory);

    function getGranaryLendingTokens(address token) external view returns (AaveTokens memory);

    function getVenusLendingTokens(address token) external view returns (address);
    function getVenusEthLendingTokens(address token) external view returns (address);

    function getCometToBase(address token) external view returns (address);
}

abstract contract ChainBase is IChainBase {
    address internal constant NOT_AVAILABLE = address(uint160(uint256(keccak256("NOT_AVAILABLE"))));

    mapping(uint256 chainId => mapping(string tokenName => address tokenAddress)) public tokens;
    mapping(address baseToken => AaveTokens lendingToken) public AaveV3LendingTokens;
    mapping(address baseToken => AaveTokens lendingToken) public GraneryLendingTokens;

    mapping(address => address) public VENUS_cTokens;
    mapping(address => address) public VENUS_ETH_cTokens;
    mapping(address => address) public CometToBase;

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

    function getAaveV3LendingTokens(address token) public view returns (AaveTokens memory) {
        return AaveV3LendingTokens[token];
    }

    function getGranaryLendingTokens(address token) external view returns (AaveTokens memory) {
        return GraneryLendingTokens[token];
    }

    function getVenusLendingTokens(address token) external view returns (address) {
        return VENUS_cTokens[token];
    }

    function getVenusEthLendingTokens(address token) external view returns (address) {
        return VENUS_ETH_cTokens[token];
    }

    function getCometToBase(address token) external view returns (address) {
        return CometToBase[token];
    }
}
