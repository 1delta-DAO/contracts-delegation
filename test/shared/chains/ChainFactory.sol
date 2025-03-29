// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ChainInitializer.sol";
import {Chains} from "../../data/LenderRegistry.sol";

/// @title ChainFactory
/// @notice A factory for creating chains to be used in the tests
contract ChainFactory {
    /// @notice Get a chain for a given chain name
    /// @dev the chainName must be a valid chain name in the Chains library
    /// @param chainName The name of the chain to get the initializer for
    /// @return The chain for the given chain name
    function getChain(string memory chainName) public returns (IChain) {
        return new Chain(chainName);
    }
}
