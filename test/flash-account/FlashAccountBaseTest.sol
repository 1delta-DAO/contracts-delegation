// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {ChainFactory} from "./chain/ChainFactory.sol";
import {IChainBase} from "./chain/ChainBase.sol";
// solhint-disable-next-line
contract FlashAccountBaseTest is Test {
    // test user
    uint256 internal userPrivateKey = 0x1de17a;
    address internal user;
    address internal owner = address(0x1);
    address payable internal constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    IChainBase internal chain;

    EntryPoint internal entryPoint;
    FlashAccount internal userFlashAccount;

    function setUp() public virtual {
        // setup user
        user = vm.addr(userPrivateKey);

        // get chain-id from env
        uint256 chainId = uint256(vm.envOr("CHAIN_ID", int256(43114)));

        // get chain from chainFactory
        ChainFactory chainFactory = new ChainFactory();
        chain = chainFactory.getChain(chainId);

        // create a fork (setting a specific block number on free wont work most of the times)
        uint256 forkId = vm.createSelectFork(chain.getRpcUrl());
        entryPoint = new EntryPoint();

        // Accounts
        FlashAccount flashAccountImplementation = new FlashAccount(entryPoint);
        UpgradeableBeacon beacon = new UpgradeableBeacon(owner, address(flashAccountImplementation));
        FlashAccountFactory flashAccountFactory = new FlashAccountFactory(owner, address(beacon), entryPoint);
        userFlashAccount = FlashAccount(payable(flashAccountFactory.createAccount(user, 1)));

        // deal some eth to the user and userAccount
        vm.deal(user, 100 ether);
        vm.deal(address(userFlashAccount), 100 ether);
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _getUnsignedOp(bytes memory callData, uint256 nonce) internal view returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;
        return
            PackedUserOperation({
                sender: address(userFlashAccount),
                nonce: nonce,
                initCode: "",
                callData: callData,
                accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
                preVerificationGas: 1 << 24,
                gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
                paymasterAndData: "",
                signature: ""
            });
    }
}
