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

contract ForkTestMetis is BaseTest {
    IComposerLike oneDV2;

    address admin = 0xAd723f9A94D8b295781311ca4Ec31D5aBAe07c4f;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0xCe434378adacC51d54312c872113D687Ac19B516;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.METIS_ANDROMEDA_MAINNET;

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

    function test_fork_raw_metis() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0.1e18}(getData());
    }

    function test_fork_params_metis() external {
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
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000ee100000000000000000016345785d8a00000000000000000000000000000013bcac00000000000000000000000000000000000000000100000075cb093e4d61d2a2e65d8e0bbb01de8d89b53481ce434378adacc51d54312c872113d687ac19b516fe000201000000420000000000000000000000000000000000000ace434378adacc51d54312c872113d687ac19b51600bd718c67cd1e2f7fbe22d47be21036cd647c77141e0bb800010000ea32a96608495e54156ae48931a7c20f0dcc1a2191ae002a960e63ccb0e5bde83a8c13e51e1cb91a01effec28996aaff6d55b6d108a46446d45c3a2e7126f2880001000000000000000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0.1e18;
        d =
            hex"100000000000000000016345785d8a0000000000000000000000fab949906e166700000000000000000000000000000000000000000100000075cb093e4d61d2a2e65d8e0bbb01de8d89b53481ce434378adacc51d54312c872113d687ac19b516fe000200030000000099990000000000000000000000000000000000000000000000000000000000003333000000000000000000000000000000000000000000000000000000000000199902000000ea32a96608495e54156ae48931a7c20f0dcc1a21ce434378adacc51d54312c872113d687ac19b51600a4e4949e0cccd8282f30e7e113d8a551a1ed1aeb1e06d500010000bb06dca3ae6887fabf931640f67cab3e3a16f4dcce434378adacc51d54312c872113d687ac19b51600926873c13835e44516073aa6b45e56116efa59b410006400010000deaddeaddeaddeaddeaddeaddeaddeaddead0000ce434378adacc51d54312c872113d687ac19b51600ceb9452a3bd2df1bffbd9918a4ba257b13a00873100bb8000102000000ea32a96608495e54156ae48931a7c20f0dcc1a21ce434378adacc51d54312c872113d687ac19b51600f956887f404883a838a388b7884ca85b223bd54d010bb800010000420000000000000000000000000000000000000ace434378adacc51d54312c872113d687ac19b51600426b43699e671b202d5c45bbfd62a249ac7f95d810006400010000deaddeaddeaddeaddeaddeaddeaddeaddead0000ce434378adacc51d54312c872113d687ac19b51600dc984005f06b10dd34dd38afd4cb6284296f5039102710000101000000bb06dca3ae6887fabf931640f67cab3e3a16f4dcce434378adacc51d54312c872113d687ac19b516004680b3f8888f4ea12535ad3b601dce2023ae5c550f0bb800010000deaddeaddeaddeaddeaddeaddeaddeaddead0000ce434378adacc51d54312c872113d687ac19b516001ff5d5fc9269e5435815e502a56f775e83809b3f100064000102000000ea32a96608495e54156ae48931a7c20f0dcc1a21ce434378adacc51d54312c872113d687ac19b51601ef874fede49cf49940e8c472f3e58e75ea65b34c26f28200010000420000000000000000000000000000000000000ace434378adacc51d54312c872113d687ac19b51600d843a4a69db2f5a908c8bb9cca3d5cf4242d61331001f400010000deaddeaddeaddeaddeaddeaddeaddeaddead0000ce434378adacc51d54312c872113d687ac19b51600eb659cc5a051c5520957dadbfe801bf14ec3ceb910006400014005deaddeaddeaddeaddeaddeaddeaddeaddead000090df02551bb792286e8d4f13e0e357b4bf1d6a57300003e7deaddeaddeaddeaddeaddeaddeaddeaddead00000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a90df02551bb792286e8d4f13e0e357b4bf1d6a574001deaddeaddeaddeaddeaddeaddeaddeaddead000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000000000";
    }
}
