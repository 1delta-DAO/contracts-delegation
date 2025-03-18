// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "../shared/chains/ChainFactory.sol";
import "../shared/chains/ChainInitializer.sol";
import "../data/LenderRegistry.sol";

contract BaseTest is Test {
    IChain internal chain;
    address internal user;
    uint256 internal userPrivateKey;
    address payable internal constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    ChainFactory internal chainFactory;

    /// @notice Initialize the chain for the test
    /// @dev The chainName must be a valid chain name in the Chains library
    /// @param chainName The name of the chain to initialize
    function _init(string memory chainName) internal {
        chainFactory = new ChainFactory();
        chain = chainFactory.getChain(chainName);

        // Initialize user
        userPrivateKey = 0x1de17a;
        user = vm.addr(userPrivateKey);
        vm.deal(user, 100 ether);

        // Create a fork
        string memory rpcUrl = chain.getRpcUrl();
        vm.createSelectFork(rpcUrl);
    }

    /// @notice Utility function for signing messages
    /// @param privateKey The private key of the user
    /// @param digest The digest of the message to sign
    /// @return The signed message
    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @notice Utility function for signing messages with the user's private key
    /// @param digest The digest of the message to sign
    /// @return The signed message
    function _signUser(bytes32 digest) internal view returns (bytes memory) {
        return _sign(userPrivateKey, digest);
    }
}
