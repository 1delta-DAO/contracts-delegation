// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

import "../../../contracts/external-protocols/misc/FeeOnTransferDetector.sol";
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

    uint256 internal constant forkBlock = 358310231;

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

    function test_fork_raw_arb_swap() external {
        vm.prank(mockSender);
        IComposerLike(proxy).deltaCompose{value: 0.0e18}(getData());
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

    function getData() internal pure returns (bytes memory d) {
        d =
            hex"8000ba1333333333a1ba1108e8412f11850a5c319ba90276008004ba1333333333a1ba1108e8412f11850a5c319ba9af88d065e77c8cc2239327c5edb3a432268e5831fca1154c643c32638aee9a43eee7f377f515c80100000000000000000000000000222a4e20fca1154c643c32638aee9a43eee7f377f515c8010000000000000000000000000000000000fc4005af88d065e77c8cc2239327c5edb3a432268e5831a669e7a0d4b3e4fa48af2de86bd4cd7126be4e1320a669e7a0d4b3e4fa48af2de86bd4cd7126be4e130000000000000000000000000000000000ab83bd37f9000a000f03222a4e08025a3b5f40c74ae0028f5c000184ff2ddf2bc84e37ed3bd2d0192e8534d12574f10000000105f3f58716a88a52493be45aa0871c55b3748f180000000003010203000c0101010201000bb800003c00ff0000000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a0000000000000000000000000000000000000000000000004005fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a9c4ec768c28520b50860ea7a15bd7213a9ff58bf30000bb7fc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a00000000000000000000000000000000bada9c382165b31419f4cc0edf0fa84f80a3c8e59c4ec768c28520b50860ea7a15bd7213a9ff58bf30010bb7af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000222a4e05f3f58716a88a52493be45aa0871c55b3748f189c4ec768c28520b50860ea7a15bd7213a9ff58bf8005ba1333333333a1ba1108e8412f11850a5c319ba9af88d065e77c8cc2239327c5edb3a432268e583100000000000000000000000000222a4e";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"5000420000000000000000000000000000000000000600600000000000000000000000000000018e286cefcf6854056a000000006854056abbb22fa9f977b3687528f18d6e662eb4f7627a8a65a0a087612344c0efc2ded6e9bc8618c9a4dbe4f9f6e04a2933af0acaad92bbd71dbac2f8b6c3e3d8fa483540044200000000000000000000000000000000000006b7ea94340e65cc68d1274ae483dfbe593fd6f21e00000000000000000000018dc29953d340054200000000000000000000000000000000000006a238dd80c259a72e81d7e4664a9801593f98d1c5300003e7420000000000000000000000000000000000000600000000000000000000018dc29953d391ae002a960e63ccb0e5bde83a8c13e51e1cb91aa238dd80c259a72e81d7e4664a9801593f98d1c5";
    }
}

// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2000000000000000000000000000000000000000000000000000000000000001c4e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2bfa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc23fa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e1c
