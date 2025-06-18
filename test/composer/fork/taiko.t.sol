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

    uint256 internal constant forkBlock = 1212082;

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
        address(proxy).call{value: 0.0015e18}(getData());
    }

    function test_fork_params_taiko() external {
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
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a81000000000000000000005543df729c000000000000000000000000000000009f4000000000000000000000000000000000000000001000000a51894664a773981c6c112c43ce576f315d5b1b6594ce4b82a81930cc637f1a59afdfb0d70054232fe00020000c4c410459fbaf8f7f86b6cee52b4fa1282ff970491ae002a960e63ccb0e5bde83a8c13e51e1cb91a0091c57e1b83fab37f693f8453478b85214e1899ee0201020001000000000000000000000000000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 1000000000000000;
        d =
            hex"20fca1154c643c32638aee9a43eee7f377f515c801000000000000000000038d7ea4c6800001372063d3c7ab37ca36a2a0a338076c163ff60c72527c000000000000000000038d7ea4c6800000d53f0bde25107fb4fe60cd05a3e68668007cee83ddfd9a50a45b36000000000000000000038d7ea4c680000000000000000000000017061d4baeda07b4fe60cd05a3e68668007cee83ddfd9a50a45b360bd7473cbbf81d9dd936c61117ed230d95006ca2eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeef7fb2df9280eb0a76427dc3b34761db8b1441a49a51894664a773981c6c112c43ce576f315d5b1b6e1f84312952a6f98444e65d0b1a8f7b55609b13e2bfd1fc5e25a8f55c2e849492ad7966ea8a0dd9e540406050453030600af510301ff4001f7fb2df9280eb0a76427dc3b34761db8b1441a4991ae002a960e63ccb0e5bde83a8c13e51e1cb91a00000000000000000000000000000000004001000000000000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000000000";
    }
}
