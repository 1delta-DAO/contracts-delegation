// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Base.sol";

contract ChainFactory {
    function getChain(uint256 chainId) public returns (IChainBase) {
        if (chainId == ChainIds.BASE) {
            return new Base();
        } else {
            revert("Chain not supported");
        }
    }
}
