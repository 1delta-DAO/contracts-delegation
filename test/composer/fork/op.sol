// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

import "../../../contracts/external-protocols/misc/FeeOnTransferDetector.sol";
import "./ECSDA.sol";

// solhint-disable max-line-length

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract ForkTestMantle is BaseTest {
    IComposerLike oneDV2;

    address admin = 0x9ACC4fbBe3237e8f04173ECA2c5b19c277305f56;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0xCDef0A216fcEF809258aA4f341dB1A5aB296ea72;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 137371492;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.OP_MAINNET;

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

    function test_fork_raw_op_swap() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0.0e18}(getData());
    }

    function test_fork_params_op() external {
        console.log(mockSender.code.length);

        bytes memory xx =
            hex"b2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc23fa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e1c";
        ECDSA.tryRecover(0x4e972a8fa179a59873c8c82d709127a76e4002a62ec5075e19835f1f0f7b5248, xx);
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
            hex"50004200000000000000000000000000000000000006006000000000000000000000000000007c8e16ee6014685420720000000168542072b2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2bfa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e40044200000000000000000000000000000000000006cdef0a216fcef809258aa4f341db1a5ab296ea72000000000000000000007c6e3c3f354640054200000000000000000000000000000000000006794a61358d6845594f94dc1db02a252b5b4814ad300003e74200000000000000000000000000000000000006000000000000000000007c6e3c3f354691ae002a960e63ccb0e5bde83a8c13e51e1cb91a794a61358d6845594f94dc1db02a252b5b4814ad";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"50004200000000000000000000000000000000000006006000000000000000000000000000007c8e16ee6014685420720000000168542072b2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2bfa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e40044200000000000000000000000000000000000006cdef0a216fcef809258aa4f341db1a5ab296ea72000000000000000000007c6e3c3f354640054200000000000000000000000000000000000006794a61358d6845594f94dc1db02a252b5b4814ad300003e74200000000000000000000000000000000000006000000000000000000007c6e3c3f354691ae002a960e63ccb0e5bde83a8c13e51e1cb91a794a61358d6845594f94dc1db02a252b5b4814ad";
    }
}
