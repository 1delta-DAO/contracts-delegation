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

    constructor() {
        _initRpcOverrides();
    }

    function _initRpcOverrides() internal {
        _setRpcOverride(Chains.ARBITRUM_ONE, "RPC_ARBITRUM_ONE");
        _setRpcOverride(Chains.AVALANCHE_C_CHAIN, "RPC_AVALANCHE_C_CHAIN");
        _setRpcOverride(Chains.BASE, "RPC_BASE");
        _setRpcOverride(Chains.BERACHAIN, "RPC_BERACHAIN");
        _setRpcOverride(Chains.BLAST, "RPC_BLAST");
        _setRpcOverride(Chains.CELO_MAINNET, "RPC_CELO_MAINNET");
        _setRpcOverride(Chains.CORE_BLOCKCHAIN_MAINNET, "RPC_CORE_BLOCKCHAIN_MAINNET");
        _setRpcOverride(Chains.CRONOS_MAINNET, "RPC_CRONOS_MAINNET");
        _setRpcOverride(Chains.ETHEREUM_MAINNET, "RPC_ETHEREUM_MAINNET");
        _setRpcOverride(Chains.FANTOM_OPERA, "RPC_FANTOM_OPERA");
        _setRpcOverride(Chains.HEMI_NETWORK, "RPC_HEMI_NETWORK");
        _setRpcOverride(Chains.HYPEREVM, "RPC_HYPEREVM");
        _setRpcOverride(Chains.KAIA_MAINNET, "RPC_KAIA_MAINNET");
        _setRpcOverride(Chains.KATANA, "RPC_KATANA");
        _setRpcOverride(Chains.LINEA, "RPC_LINEA");
        _setRpcOverride(Chains.MANTA_PACIFIC_MAINNET, "RPC_MANTA_PACIFIC_MAINNET");
        _setRpcOverride(Chains.MANTLE, "RPC_MANTLE");
        _setRpcOverride(Chains.METIS_ANDROMEDA_MAINNET, "RPC_METIS_ANDROMEDA_MAINNET");
        _setRpcOverride(Chains.MODE, "RPC_MODE");
        _setRpcOverride(Chains.MOONBEAM, "RPC_MOONBEAM");
        _setRpcOverride(Chains.MORPH, "RPC_MORPH");
        _setRpcOverride(Chains.MONAD_MAINNET, "RPC_MONAD_MAINNET");
        _setRpcOverride(Chains.OP_MAINNET, "RPC_OP_MAINNET");
        _setRpcOverride(Chains.BNB_SMART_CHAIN_MAINNET, "RPC_BNB_SMART_CHAIN_MAINNET");
        _setRpcOverride(Chains.GNOSIS, "RPC_GNOSIS");
        _setRpcOverride(Chains.PLASMA_MAINNET, "RPC_PLASMA_MAINNET");
        _setRpcOverride(Chains.POLYGON_MAINNET, "RPC_POLYGON_MAINNET");
        _setRpcOverride(Chains.PULSECHAIN, "RPC_PULSECHAIN");
        _setRpcOverride(Chains.SCROLL, "RPC_SCROLL");
        _setRpcOverride(Chains.SEI_NETWORK, "RPC_SEI_NETWORK");
        _setRpcOverride(Chains.SONEIUM, "RPC_SONEIUM");
        _setRpcOverride(Chains.SONIC_MAINNET, "RPC_SONIC_MAINNET");
        _setRpcOverride(Chains.TAIKO_ALETHIA, "RPC_TAIKO_ALETHIA");
        _setRpcOverride(Chains.TELOS_EVM_MAINNET, "RPC_TELOS_EVM_MAINNET");
        _setRpcOverride(Chains.UNICHAIN, "RPC_UNICHAIN");
        _setRpcOverride(Chains.XDC_NETWORK, "RPC_XDC_NETWORK");
    }

    function _setRpcOverride(string memory chainName, string memory envVar) internal {
        string memory rpc = _getEnvRpc(envVar);
        if (bytes(rpc).length > 0) {
            rpcOverrides[chainName] = rpc;
        }
    }

    function _getEnvRpc(string memory envVar) internal view returns (string memory) {
        try vm.envString(envVar) returns (string memory rpc) {
            return rpc;
        } catch {
            return "";
        }
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
            ILendingTools(instance)
                .approveDelegation(
                    spender, //
                    type(uint256).max
                );
        } else if (Lenders.isCompoundV2(lender)) {
            address instance = chain.getLendingController(lender);
            vm.prank(_user);
            ILendingTools(instance)
                .updateDelegate(
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
            ILendingTools(instance)
                .allow(
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
            ILendingTools(instance)
                .approve(
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
            ILendingTools(instance)
                .allow(
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
