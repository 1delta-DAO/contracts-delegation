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

contract ForkTestMantle is BaseTest {
    IComposerLike oneDV2;

    address admin = 0xe717cF8aFFA37c6e03C986452a19348Ab6Cb6197;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x5C019a146758287C614FE654CaEC1ba1CaF05F4E;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 80991129;

    address internal constant factory = 0xF38E7c7f8eA779e8A193B61f9155E6650CbAE095;
    bool internal constant isSolidly = false;
    bytes32 internal constant codeHash = 0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.MANTLE;

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

    function test_fork_raw_mantle_swap() external {
        vm.prank(mockSender);
        address(0xc08BFef7E778f3519D79E96780b77066F5d4FCC0).call{value: 0.2e18}(getData());
    }

    function test_fork_params_mantle() external {
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
            hex"ac9650d8000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000001e41f8ba8d6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002c68af0bb1400000000000000000000000000005c019a146758287c614fe654caec1ba1caf05f4e0000000000000000000000005c019a146758287c614fe654caec1ba1caf05f4e00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000010417d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a810000000000000000002c68af0bb140000000000000000000000000000000164b700000000000000000000000000000000000000000100000078c1b0c915c4faa5fffa6cabf0219da63d7f4cb85c019a146758287c614fe654caec1ba1caf05f4efe0002000009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9c08bfef7e778f3519d79e96780b77066f5d4fcc00114bdf0998a2313f8e5772866fdac029f3d58eb2b270f4000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef2400000000000000000000000009bc4e0d864854c6afb6eb9a9cdf58ac190d0df91ce1e33eb623b9fa2805955bc9e4f6afb24f32bae81d2b601a25fa226ee136c400000000000000000000000000000000000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"100000000000000006fab6b9106fe461a900000000000000000108093d7c88eb5e186573b175adf5801cf95fb06b232ccab123c6f4010002000000420000000000000000000000000000000000000af5988809ac97c65121e2c34f5d49558e3d12c253036d2d52d788a5eab4009dc4e039505212f444bf6426f28200000000ea32a96608495e54156ae48931a7c20f0dcc1a21ef874fede49cf49940e8c472f3e58e75ea65b34c01f5988809ac97c65121e2c34f5d49558e3d12c25326f2000002000075cb093e4d61d2a2e65d8e0bbb01de8d89b53481ce434378adacc51d54312c872113d687ac19b51601ef874fede49cf49940e8c472f3e58e75ea65b34c26f28200020000000000000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91afe0001";
    }
}
