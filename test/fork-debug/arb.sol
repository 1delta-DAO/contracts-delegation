// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

import "contracts/external-protocols/misc/FeeOnTransferDetector.sol";
import "./FOT.sol";

// solhint-disable max-line-length

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract ForkTestArb is BaseTest {
    IComposerLike oneDV2;

    address admin = 0x492d53456Cc219A755Ac5a2d8598fFd6F47A9fD1;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x05f3f58716a88A52493Be45aA0871c55b3748f18;

    address mockSender = 0xbadA9c382165b31419F4CC0eDf0Fa84f80A3C8E5;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock, true);

        oneDV2 = ComposerPlugin.getComposer(chainName);

        vm.prank(owner);
        IA(admin).upgradeAndCall(proxy, address(oneDV2), hex"");

        labelAddresses();
    }

    function labelAddresses() internal {
        vm.label(owner, "owner");
        vm.label(admin, "admin");
        vm.label(proxy, "proxy");
        vm.label(address(oneDV2), "Composer");
        vm.label(mockSender, "MeMeMeMe");
    }

    // function test_fork_raw_arb_swap() external {
    //     vm.prank(mockSender);
    //     address(proxy).call{value: 0.0e18}(getData());
    // }

    function test_fork_raw_arb_perm() external {
        address a;
        bytes memory data;
        (data, a) = getDataPrepPerm();
        deal(a, mockSender, 3e18);
        // prep
        vm.prank(mockSender);
        address(a).call{value: 0.0e18}(data);
        (data, a) = getDataPrep();
        vm.prank(mockSender);
        address(a).call{value: 0.0e18}(data);

        // txn
        (data, a) = getDataPerm();
        vm.prank(mockSender);
        address(a).call{value: 0.0e18}(data);
        (data, a) = getData();
        vm.prank(mockSender);
        address(a).call{value: 0.0e18}(data);
    }

    function test_fork_raw_arb_single() external {
        address a;
        bytes memory data;
        (data, a) = getDataPrepPerm();
        deal(a, mockSender, 3e18);
        vm.deal(mockSender, 3e18);
        // // prep
        // vm.prank(mockSender);
        // address(a).call{value: 0.0e18}(data);
        // (data, a) = getDataPrep();
        // vm.prank(mockSender);
        // address(a).call{value: 0.0e18}(data);

        // // txn
        // (data, a) = getDataPerm1();
        // vm.prank(mockSender);
        // address(a).call{value: 0.0e18}(data);
        (data, a) = getData1();
        vm.prank(mockSender);
        address(a).call{value: 1.0e18}(data);
    }

    function test_fork_params_arb() external {
        vm.prank(mockSender);
        (bytes memory params, uint256 value) = getParams2();
        IComposerLike(proxy).deltaCompose{value: value}(params);
    }

    // nonce 0n
    // cometCreditPermit.ts:120 expiry 1748970849
    // cometCreditPermit.ts:121 v,r,s 27n 0x8c2ebd619f0fef85520e275e95f372e76a6442b28cfe60b76547baca0decc64f 0x16eac8a7b9737f99696f09db674e26ce6e362eb4036153e70a5f9da3eece7aab
    // cometCreditPermit.ts:126 r 8c2ebd619f0fef85520e275e95f372e76a6442b28cfe60b76547baca0decc64f
    // cometCreditPermit.ts:127 vs 16eac8a7b9737f99696f09db674e26ce6e362eb4036153e70a5f9da3eece7aab

    function getData1() internal pure returns (bytes memory d, address a) {
        a = address(0x05f3f58716a88A52493Be45aA0871c55b3748f18);
        d =
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b4400682af49447d8a07e3bd95bd0d56f35241523fbab105f3f58716a88a52493be45aa0871c55b3748f1800000000000000000de0b6b3a7640000400582af49447d8a07e3bd95bd0d56f35241523fbab16f7d514bbd4aff3bcd1140b7344b32f063dee48630000bb782af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000de0b6b3a76400007e5f4552091a69125d5dfcb7b8c2659029395bdf6f7d514bbd4aff3bcd1140b7344b32f063dee486000000000000000000000000";
    }

    function getData() internal pure returns (bytes memory d, address a) {
        a = address(0x05f3f58716a88A52493Be45aA0871c55b3748f18);
        d =
            hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000008c30030bb782af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000006f05b59d3b2000005f3f58716a88a52493be45aa0871c55b3748f18016f7d514bbd4aff3bcd1140b7344b32f063dee486400382af49447d8a07e3bd95bd0d56f35241523fbab17e5f4552091a69125d5dfcb7b8c2659029395bdf01000000000000000006f05b59d3b200000000000000000000000000000000000000000000";
    }

    function getDataPrepPerm() internal pure returns (bytes memory d, address a) {
        a = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        d =
            hex"095ea7b30000000000000000000000006f7d514bbd4aff3bcd1140b7344b32f063dee4860000000000000000000000000000000000000000000000001bc16d674ec80000";
    }

    function getDataPrep() internal pure returns (bytes memory d, address a) {
        a = address(0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486);
        d =
            hex"f2b9fdb800000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000001bc16d674ec80000";
    }

    function getDataPerm() internal pure returns (bytes memory d, address a) {
        a = address(0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486);
        d =
            hex"110496e500000000000000000000000005f3f58716a88a52493be45aa0871c55b3748f180000000000000000000000000000000000000000000000000000000000000001";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"400582af49447d8a07e3bd95bd0d56f35241523fbab16c247b1f6182318877311737bac0844baa518f5e600082af49447d8a07e3bd95bd0d56f35241523fbab16c247b1f6182318877311737bac0844baa518f5e000000000000000000ac1cecb641b36c056d00400582af49447d8a07e3bd95bd0d56f35241523fbab19c4ec768c28520b50860ea7a15bd7213a9ff58bf30000bb782af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000ac1cecb641b36cbada9c382165b31419f4cc0edf0fa84f80a3c8e59c4ec768c28520b50860ea7a15bd7213a9ff58bf30030bb757f5e098cad7a3d1eed53991d4d66c45c9af78120000000000000000016345785d8a000005f3f58716a88a52493be45aa0871c55b3748f18009c4ec768c28520b50860ea7a15bd7213a9ff58bf400157f5e098cad7a3d1eed53991d4d66c45c9af781205f3f58716a88a52493be45aa0871c55b3748f18010000000000000000016345785d8a000020fca1154c643c32638aee9a43eee7f377f515c801000000000000000000000000000000000374400557f5e098cad7a3d1eed53991d4d66c45c9af78121111111254eeb25477b68fb85ed929f73a960582201111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000002e812aa3caf000000000000000000000000de9e4fe32b049f821c7f3e9802381aa470ffca7300000000000000000000000057f5e098cad7a3d1eed53991d4d66c45c9af781200000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000de9e4fe32b049f821c7f3e9802381aa470ffca7300000000000000000000000005f3f58716a88a52493be45aa0871c55b3748f18000000000000000000000000000000000000000000000000016345785d8a000000000000000000000000000000000000000000000000000000001a39e32d47500000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014200000000000000000000000000000000000000000000000000012400004e00a0744c8c0957f5e098cad7a3d1eed53991d4d66c45c9af781290cbe4bdd538d6e9b379bff5fe72c3d67a521de5000000000000000000000000000000000000000000000000000110d9316ec00000a007e5c0d20000000000000000000000000000000000000000000000000000b200004f02a0000000000000000000000000000000000000000000000000000015c47f9c71dbee63c1e501f9ba609869a46c06be6689fc0a314ce5f4fdad4157f5e098cad7a3d1eed53991d4d66c45c9af781202a000000000000000000000000000000000000000000000000000001a39e32d4750ee63c1e58135218a1cbac5bbc3e57fd9bd38219d37571b35375979d7b546e38e414f7e9822514be443a48005291111111254eeb25477b68fb85ed929f73a960582000000000000000000000000000000000000000000000000000000000000dc2cbb78400182af49447d8a07e3bd95bd0d56f35241523fbab105f3f58716a88a52493be45aa0871c55b3748f180000000000000000000000000000000000400582af49447d8a07e3bd95bd0d56f35241523fbab19c4ec768c28520b50860ea7a15bd7213a9ff58bf30000bb782af49447d8a07e3bd95bd0d56f35241523fbab100000000000000000000000000000000bada9c382165b31419f4cc0edf0fa84f80a3c8e59c4ec768c28520b50860ea7a15bd7213a9ff58bf30030bb782af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000ac1cecb641b36c05f3f58716a88a52493be45aa0871c55b3748f18009c4ec768c28520b50860ea7a15bd7213a9ff58bf";
    }
}

// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2000000000000000000000000000000000000000000000000000000000000001c4e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2bfa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc23fa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e1c
