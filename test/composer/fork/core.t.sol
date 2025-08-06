// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract ForkTestCore is BaseTest {
    IComposerLike oneDV2;

    // arb
    // address admin = 0x492d53456Cc219A755Ac5a2d8598fFd6F47A9fD1;
    // address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    // address proxy = 0x05f3f58716a88A52493Be45aA0871c55b3748f18;

    // op
    address admin = 0xb63E6455858887C8F6bda75C44c41570be989597;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.CORE_BLOCKCHAIN_MAINNET;

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

    function test_fork_raw_core() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0.001e18}(getData());
    }

    function test_fork_params_core() external {
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
            hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000013610000000000000000000038d7ea4c680000000000000000000000000000000064b000000000000000000000000000000000000000001000000420000000000000000000000000000000000000679f4061bf049c5c6cac6bfe2415c2460815f4ac7fe00020001e6650000aa40c0c7644e0b2b224509571e10ad20d9c4ef2891ae002a960e63ccb0e5bde83a8c13e51e1cb91a00dc5ebab82ba76ccf5eab9c32aef228a1eb77a781000bb8000101000000ad11a8beb98bbf61dbb1aa0f6d6f2ecd87b35afa01b6c8d4bd055d3d3f535a39c20d4c7d60f3e55a96e410d276ce04b98458924ed16b8cf33b40a271e600000000010000aa40c0c7644e0b2b224509571e10ad20d9c4ef2891ae002a960e63ccb0e5bde83a8c13e51e1cb91a9601b6c8d4bd055d3d3f535a39c20d4c7d60f3e55a010000000200000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 2.0e18;
        d =
            hex"1000000000000000001bc16d674ec80000000000000000000000000000000a10d400000000000000000000000000000000000000000100000040375c92d9faf44d2f9db9bd9ba41a3317a2404f816ebc5cb8a5651c902cb06659907a93e574db0bfe00020000a4151b2b3e269645181dccf2d426ce75fcbdeca991ae002a960e63ccb0e5bde83a8c13e51e1cb91a00aeef7e59ce29b866660db4903a9c945bb4a9bcc21500c10001";
    }
}
