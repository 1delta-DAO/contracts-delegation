// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
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
    address admin = 0x9ACC4fbBe3237e8f04173ECA2c5b19c277305f56;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0xCDef0A216fcEF809258aA4f341dB1A5aB296ea72;

    address mockSender = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

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
        vm.label(0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf, "AToken Proxy");
        vm.label(0xbCb167bDCF14a8F791d6f4A6EDd964aed2F8813B, "AToken Impl");
        vm.label(0xfca11Db2b5DE60DF9a2C81233333a449983B4101, "CallForwarder");
        vm.label(0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680, "Odos Router");

        vm.label(chain.getTokenAddress(Tokens.OP), Tokens.OP);
        vm.label(chain.getTokenAddress(Tokens.WETH), Tokens.WETH);
        vm.label(chain.getTokenAddress(Tokens.USDC), Tokens.USDC);
        vm.label(chain.getTokenAddress(Tokens.USDC_E), Tokens.USDC_E);

        vm.label(chain.getTokenAddress(Tokens.USDT), Tokens.USDT);
        vm.label(chain.getTokenAddress(Tokens.WSTETH), Tokens.WSTETH);
        vm.label(0x6131B5fae19EA4f9D964eAc0408E4408b66337b5, "KyberswapRouter");
        vm.label(0xE36A30D249f7761327fd973001A32010b521b6Fd, "cWETHv3");

        vm.label(0x0000000000000000000000000000000000000000, "ZeroAddress");
        vm.label(0xce95AfbB8EA029495c66020883F87aaE8864AF92, "Morpho");
    }

    function test_fork_raw1() external {
        vm.prank(mockSender);
        address(proxy).call(getData());
    }

    function test_fork_params1() external {
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
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001d31000000000000000000021a93118e1d120000000000000000000000000000025d84200000000000000000000000000000000000006000068f180fcce6836688e9084f035309e29bf0a2095cdef0a216fcef809258aa4f341db1a5ab296ea7200319c0dd36284ac24a6b2bee73929f699b9f48c38130064015a400568f180fcce6836688e9084f035309e29bf0a2095794a61358d6845594f94dc1db02a252b5b4814ad300003e768f180fcce6836688e9084f035309e29bf0a20950000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a794a61358d6845594f94dc1db02a252b5b4814ad5000e50fa9b3c56ffb159cb0fca61f5c9d750e8128c800640000000000000000000000000000000000000000000000000021b1cf1929b9046848d618c77cd308b098965a3f3296509235f609b11d698d52699d752452f619314353fee4f2e1436f82482b29bc8bbfc91a7dd38fea3061b567f654b4b49c7e680f3363300303e742000000000000000000000000000000000000060000ffffffffffffffffffffffffffffcdef0a216fcef809258aa4f341db1a5ab296ea72e50fa9b3c56ffb159cb0fca61f5c9d750e8128c8794a61358d6845594f94dc1db02a252b5b4814ad00000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"1000000000000000000021a9314b348a1100000000000000000000000000005e774200000000000000000000000000000000000006000068f180fcce6836688e9084f035309e29bf0a2095cdef0a216fcef809258aa4f341db1a5ab296ea7200689a850f62b41d89b5e5c3465cd291374b215813010bb80195400568f180fcce6836688e9084f035309e29bf0a2095794a61358d6845594f94dc1db02a252b5b4814ad300003e768f180fcce6836688e9084f035309e29bf0a20950000000000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a794a61358d6845594f94dc1db02a252b5b4814ad5000e50fa9b3c56ffb159cb0fca61f5c9d750e8128c800640000000000000000000000000000000000000000000000000021b1cf4b8953ef6848d73c5b145e86384440efe6cf84efd21204ae69ad927fcc92bce4e74f754f86a8e0f7acefe09786da15537fdd1cee3c3ca5d5842217dd56607938259231bcff450651300303e742000000000000000000000000000000000000060000ffffffffffffffffffffffffffffcdef0a216fcef809258aa4f341db1a5ab296ea72e50fa9b3c56ffb159cb0fca61f5c9d750e8128c8794a61358d6845594f94dc1db02a252b5b4814ad40014200000000000000000000000000000000000006689a850f62b41d89b5e5c3465cd291374b2158130100000000000000000021a9314b348a11";
    }
}
