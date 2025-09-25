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

    /**
     * Some RPCs need to be hand-picked to allow forking older blocks,
     * add robust RPC urls in the constructor
     */
    mapping(string => string) internal rpcOverrides;

    constructor() Test() {
        rpcOverrides[Chains.ETHEREUM_MAINNET] = "https://ethereum.therpc.io";
        rpcOverrides[Chains.ARBITRUM_ONE] = "https://arbitrum.drpc.org";
        rpcOverrides[Chains.BNB_SMART_CHAIN_MAINNET] = "https://bsc-dataseed1.binance.org/";
        rpcOverrides[Chains.OP_MAINNET] = "https://optimism.api.onfinality.io/public";
        rpcOverrides[Chains.POLYGON_MAINNET] = "https://polygon-rpc.com";
        rpcOverrides[Chains.HYPEREVM] = "https://rpc.hyperliquid.xyz/evm";
        // rpcOverrides[Chains.TAIKO_ALETHIA] = "https://rpc.mainnet.taiko.xyz/";
    }

    /// @notice Initialize the chain for the test
    /// @dev The chainName must be a valid chain name in the Chains library
    /// @param chainName The name of the chain to initialize
    function _init(string memory chainName, uint256 blockNumber, bool fork) internal {
        chainFactory = new ChainFactory();
        chain = chainFactory.getChain(chainName);

        // Initialize user
        userPrivateKey = 0x1de17a;
        user = vm.addr(userPrivateKey);
        vm.deal(user, 100 ether);
        vm.label(user, "user");

        // Create a fork
        string memory rpcUrl = chain.getRpcUrl();

        string memory overrideRpc = rpcOverrides[chainName];
        if (bytes(overrideRpc).length > 0) {
            rpcUrl = overrideRpc;
        }
        if (fork) {
            if (blockNumber == 0) {
                // this means the latest block
                vm.createSelectFork(rpcUrl);
            } else {
                vm.createSelectFork(rpcUrl, blockNumber);
            }
        }
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

    /**
     * delegate borrow (user to spender for underlying)
     */
    function approveBorrowDelegation(address _user, address underlying, address spender, string memory lender) internal {
        if (Lenders.isAave(lender)) {
            address instance = chain.getLendingTokens(underlying, lender).debt;
            vm.prank(_user);
            ILendingTools(instance).approveDelegation(
                spender, //
                type(uint256).max
            );
        } else if (Lenders.isCompoundV2(lender)) {
            address instance = chain.getLendingController(lender);
            vm.prank(_user);
            ILendingTools(instance).updateDelegate(
                spender,
                true //
            );
        } else if (Lenders.isCompoundV3(lender)) {
            address base = chain.getCometToBase(lender);
            if (underlying == base) {
                revert("cannot have a base borrow balance for compound V3");
            }
            address instance = chain.getLendingController(lender);
            vm.prank(_user);
            ILendingTools(instance).allow(
                spender,
                true //
            );
        }
    }

    /**
     * delegate withdrawal (user to spender for underlying)
     */
    function approveWithdrawalDelegation(address _user, address underlying, address spender, string memory lender) internal {
        if (Lenders.isAave(lender)) {
            address instance = chain.getLendingTokens(underlying, lender).collateral;
            vm.prank(_user);
            ILendingTools(instance).approve(
                spender, //
                type(uint256).max
            );
        } else if (Lenders.isCompoundV2(lender)) {
            address instance = chain.getLendingTokens(underlying, lender).collateral;
            vm.prank(_user);
            ILendingTools(instance).approve(spender, type(uint256).max);
        } else if (Lenders.isCompoundV3(lender)) {
            address instance = chain.getLendingController(lender);
            vm.prank(_user);
            ILendingTools(instance).allow(
                spender,
                true //
            );
        }
    }

    function _fundUserWithToken(address token, uint256 amount) internal {
        deal(token, user, amount);
    }

    function _fundUserWithNative(uint256 amount) internal {
        vm.deal(user, amount);
    }
}
