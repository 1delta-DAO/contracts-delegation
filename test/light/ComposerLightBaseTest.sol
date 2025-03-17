// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ChainFactory} from "./chain/ChainFactory.sol";
import {IChainBase} from "./chain/ChainBase.sol";

contract ComposerLightBaseTest is Test {
    // test user
    address internal user = address(uint160(uint256(0x1de17a << 136)));

    IChainBase internal chain;

    function _init(uint256 chainId_) internal {
        // get chain-id from env
        uint256 chainId = uint256(vm.envOr("CHAIN_ID", chainId_));

        // get chain from chainFactory
        ChainFactory chainFactory = new ChainFactory();
        chain = chainFactory.getChain(chainId);

        // create a fork (setting a specific block number on free wont work most of the times)
        uint256 forkId = vm.createSelectFork(chain.getRpcUrl(), chain.getForkBlock());

        // deal some eth to the user
        vm.deal(user, 1000 ether);
    }
}
