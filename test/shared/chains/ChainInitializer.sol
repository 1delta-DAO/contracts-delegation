// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../data/LenderRegistry.sol";

interface IChain {
    function getTokenAddress(string memory tokenSymbol) external view returns (address);
    function getLendingTokens(address token, string memory protocol) external view returns (LenderTokens memory);
    function getCometToBase(string memory protocol) external view returns (address);
    function getLendingController(string memory protocol) external view returns (address);
    function getChainId() external view returns (uint256);
    function getChainName() external view returns (string memory);
    function getRpcUrl() external view returns (string memory);
}

contract Chain is LenderRegistry, IChain {
    string private chainName;

    constructor(string memory _chainName) {
        chainName = _chainName;
    }

    function getChainId() public view override returns (uint256) {
        return _getChainId(chainName);
    }

    function getChainName() public view override returns (string memory) {
        return chainName;
    }

    function getRpcUrl() public view override returns (string memory) {
        return _getChainRpc(chainName);
    }

    function getTokenAddress(string memory tokenSymbol) public view override returns (address) {
        address tokenAddress = tokens[chainName][tokenSymbol];
        require(tokenAddress != address(0), "Token not available for this chain");
        return tokenAddress;
    }

    function getLendingTokens(address token, string memory lender) public view override returns (LenderTokens memory) {
        return lendingTokens[chainName][lender][token];
    }

    function getCometToBase(string memory lender) public view override returns (address) {
        return cometToBase[chainName][lender];
    }

    function getLendingController(string memory lender) public view override returns (address) {
        return lendingControllers[chainName][lender];
    }
}
