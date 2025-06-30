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

contract ForkTest is BaseTest {
    IComposerLike oneDV2;

    // arb
    // address admin = 0x492d53456Cc219A755Ac5a2d8598fFd6F47A9fD1;
    // address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    // address proxy = 0x05f3f58716a88A52493Be45aA0871c55b3748f18;

    // op
    address admin = 0x06289Dbafd2a697179A401e86bd2A9322F57beDf;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x594cE4B82A81930cC637f1A59afdFb0D70054232;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 1234585;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.TAIKO_ALETHIA;

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

        vm.label(chain.getTokenAddress(Tokens.WETH), Tokens.WETH);
        vm.label(chain.getTokenAddress(Tokens.USDC_E), Tokens.USDC_E);

        vm.label(chain.getTokenAddress(Tokens.USDT), Tokens.USDT);
    }

    function test_fork_raw_taiko() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0.0e18}(getData());
    }

    function test_fork_params_taiko() external {
        vm.prank(address(0xC4d8cA9da9Df454288e7210B112BE912deE700BE));
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
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000003c0400507d83526730c7438048d55a4fc0b850e2aab6f0b4ab85bf9ea548410023b25a13031e91b4c4f3b91600207d83526730c7438048d55a4fc0b850e2aab6f0b4ab85bf9ea548410023b25a13031e91b4c4f3b9100000000000000000000000003197500035a51400107d83526730c7438048d55a4fc0b850e2aab6f0bfca1154c643c32638aee9a43eee7f377f515c801010000000000000000000000000319750020fca1154c643c32638aee9a43eee7f377f515c80100000000000000000000000000000000019d400507d83526730c7438048d55a4fc0b850e2aab6f0b63d3c7ab37ca36a2a0a338076c163ff60c72527c2063d3c7ab37ca36a2a0a338076c163ff60c72527c00000000000000000000000000000000014c3f0bde2591cab4fe60cd05a3e68668007cee83ddfd9a50a45b3600000000000000000000000003190f7c000000000000000727a68db22c6740000cb4fe60cd05a3e68668007cee83ddfd9a50a45b36594ce4b82a81930cc637f1a59afdfb0d7005423207d83526730c7438048d55a4fc0b850e2aab6f0ba9d23408b9ba935c230493c40c73824df71a097512c1faa6195b8a81140deaf9c25b8f15237be829622f6796aeb2447edc31e9f0cf599b65018f8d70a51894664a773981c6c112c43ce576f315d5b1b6e47a76e15a6f3976c8dc070b3a54c7f7083d668b441da7d4de26161d8bae64b1b59b2543b7cf6303fbbeafee838fc79543423be3f06af258a8b74e9375f952a59ec5a3742f1b841775b96b196d79c43f2bfd1fc5e25a8f55c2e849492ad7966ea8a0dd9e0e04029f890605060e0702cbed0608065102092e0a022c0653030b0169510301ff4005a9d23408b9ba935c230493c40c73824df71a09753a2fd8a16030ffa8d66e47c3f1c0507c673c841e300007cfa9d23408b9ba935c230493c40c73824df71a097500000000000000000000000000000000c4d8ca9da9df454288e7210b112be912dee700be3a2fd8a16030ffa8d66e47c3f1c0507c673c841e500079a741ebfe9c323cf63180c405c050cdd98c21d80064000000000000000000000000000000000000000000000000000000000319750168628767c5c5c76a895eaf75296b9ab787dfbcaf332f02bc43cea0367033e1dd3f6d259b2e62f5b2afa1d66c401bf4dde97c90f1f20ebe75e9c752c7d2677a84865a2fe2300307cf07d83526730c7438048d55a4fc0b850e2aab6f0b0000000000000000000000000319da91594ce4b82a81930cc637f1a59afdfb0d7005423279a741ebfe9c323cf63180c405c050cdd98c21d83a2fd8a16030ffa8d66e47c3f1c0507c673c841e";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 1000000000000000;
        d =
            hex"20fca1154c643c32638aee9a43eee7f377f515c801000000000000000000038d7ea4c6800001372063d3c7ab37ca36a2a0a338076c163ff60c72527c000000000000000000038d7ea4c6800000d53f0bde25107fb4fe60cd05a3e68668007cee83ddfd9a50a45b36000000000000000000038d7ea4c680000000000000000000000017061d4baeda07b4fe60cd05a3e68668007cee83ddfd9a50a45b360bd7473cbbf81d9dd936c61117ed230d95006ca2eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeef7fb2df9280eb0a76427dc3b34761db8b1441a49a51894664a773981c6c112c43ce576f315d5b1b6e1f84312952a6f98444e65d0b1a8f7b55609b13e2bfd1fc5e25a8f55c2e849492ad7966ea8a0dd9e540406050453030600af510301ff4001f7fb2df9280eb0a76427dc3b34761db8b1441a4991ae002a960e63ccb0e5bde83a8c13e51e1cb91a00000000000000000000000000000000004001000000000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000000000";
    }
}
