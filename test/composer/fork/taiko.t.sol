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

    uint256 internal constant forkBlock = 0;

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

    function test_fork_params() external {
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
        value = 0;
        d =
            hex"40059bcef72be871e61ed4fbbc7630889bee758eb81d794a61358d6845594f94dc1db02a252b5b4814ad60029bcef72be871e61ed4fbbc7630889bee758eb81d794a61358d6845594f94dc1db02a252b5b4814ad000000000000000000333298a371642102880040019bcef72be871e61ed4fbbc7630889bee758eb81dfca11db2b5de60df9a2c81233333a449983b410101000000000000000000333298a371642120fca11db2b5de60df9a2c81233333a449983b410100000000000000000000000000000000011f40059bcef72be871e61ed4fbbc7630889bee758eb81dca423977156bb05b13a2ba3b76bc5419e2fe968020ca423977156bb05b13a2ba3b76bc5419e2fe96800000000000000000000000000000000000ce83bd37f90023000307333298a3716421073a3354a8c35c9e028f5c00014612ead0410b61b9878e292c28241789e3f87dfe00000001cdef0a216fcef809258aa4f341db1a5ab296ea7200000000040202030007010101024fd63966879300cafafbb35d157dc5229278ed2300020000000000000000002bff000000000000000000000000000000000000000000009bcef72be871e61ed4fbbc7630889bee758eb81d420000000000000000000000000000000000000600000000000000000000000000000000000000000000000040054200000000000000000000000000000000000006e36a30d249f7761327fd973001a32010b521b6fd30020bb742000000000000000000000000000000000000060000ffffffffffffffffffffffffffff91ae002a960e63ccb0e5bde83a8c13e51e1cb91ae36a30d249f7761327fd973001a32010b521b6fd30030bb79bcef72be871e61ed4fbbc7630889bee758eb81d00000000000000000033392648637eefcdef0a216fcef809258aa4f341db1a5ab296ea7200e36a30d249f7761327fd973001a32010b521b6fd4001420000000000000000000000000000000000000691ae002a960e63ccb0e5bde83a8c13e51e1cb91a00000000000000000000000000000000004001420000000000000000000000000000000000000691ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000000000";
    }
}
