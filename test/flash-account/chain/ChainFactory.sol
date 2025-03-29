// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Ethereum.sol";
import "./Avalanche.sol";

contract ChainFactory {
    function getChain(uint256 chainId) public returns (IChainBase) {
        if (chainId == ChainIds.ETHEREUM) {
            return new Ethereum();
        } else if (chainId == ChainIds.AVALANCHE) {
            return new Avalanche();
        } else {
            revert("Chain not supported");
        }
    }
}
