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

    address admin = 0x983B147a98bEAD1d4986B4c4c74c1984d0811Eb5;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0xB7ea94340e65CC68d1274aE483dfBE593fD6f21e;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

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

    function test_fork_raw_base_swap() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0.0e18}(getData());
    }

    function test_fork_params_base() external {
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
            hex"5000420000000000000000000000000000000000000600600000000000000000000000000000018e286cefcf6854056a000000006854056abbb22fa9f977b3687528f18d6e662eb4f7627a8a65a0a087612344c0efc2ded6e9bc8618c9a4dbe4f9f6e04a2933af0acaad92bbd71dbac2f8b6c3e3d8fa483540044200000000000000000000000000000000000006b7ea94340e65cc68d1274ae483dfbe593fd6f21e00000000000000000000018dc29953d340054200000000000000000000000000000000000006a238dd80c259a72e81d7e4664a9801593f98d1c5300003e7420000000000000000000000000000000000000600000000000000000000018dc29953d391ae002a960e63ccb0e5bde83a8c13e51e1cb91aa238dd80c259a72e81d7e4664a9801593f98d1c5";
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
