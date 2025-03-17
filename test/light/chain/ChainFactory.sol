// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Base.sol";
import "./ArbitrumOne.sol";

contract ChainFactory {
    function getChain(uint256 chainId) public returns (IChainBase) {
        if (chainId == ChainIds.BASE) {
            return new Base();
        } else if (chainId == ChainIds.ARBITRUM) {
            return new ArbitrumOne();
        } else {
            revert("Chain not supported");
        }
    }
}
