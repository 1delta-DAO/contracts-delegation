// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

import "../../../contracts/external-protocols/misc/FeeOnTransferDetector.sol";

// solhint-disable max-line-length

interface IA {
    function upgradeAndCall(address proxy, address implementation, bytes memory data) external;
}

contract ForkTestBnb is BaseTest {
    IComposerLike oneDV2;

    address admin = 0xb63E6455858887C8F6bda75C44c41570be989597;
    address owner = 0x999999833d965c275A2C102a4Ebf222ca938546f;
    address proxy = 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B;

    address mockSender = 0xbadA9c382165b31419F4CC0eDf0Fa84f80A3C8E5;
    // address mockSender = 0xdFF70A71618739f4b8C81B11254BcE855D02496B;

    uint256 internal constant forkBlock = 0;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BNB_SMART_CHAIN_MAINNET;

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
        // vm.label(address(oneDV2), "Composer");
        vm.label(mockSender, "MeMeMeMe");
    }

    function test_fork_raw_bnb_swap() external {
        vm.prank(mockSender);
        address(proxy).call{value: 0}(getData());
    }

    function test_fork_params_bnb() external {
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
            hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b44000bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c816ebc5cb8a5651c902cb06659907a93e574db0b000000000000000000005af3107a40004005bb4cdb9cbd36b01bd1cbaebf2de08d9173bc095ce29a55a6aeff5c8b1beede5bcf2f0cb3af8f91f5300007cfbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c000000000000000000005af3107a4000bada9c382165b31419f4cc0edf0fa84f80a3c8e5e29a55a6aeff5c8b1beede5bcf2f0cb3af8f91f5000000000000000000000000";
    }

    function getParams2() internal pure returns (bytes memory d, uint256 value) {
        value = 0;
        d =
            hex"4005c1cba3fcea344f92d9239c08c0568f6f2f0ee452bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb6000c1cba3fcea344f92d9239c08c0568f6f2f0ee452bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb00000000000000000001347644bec69a032a004001c1cba3fcea344f92d9239c08c0568f6f2f0ee452fca1154c643c32638aee9a43eee7f377f515c8010100000000000000000001347644bec69a20fca1154c643c32638aee9a43eee7f377f515c8010000000000000000000000000000000001274005c1cba3fcea344f92d9239c08c0568f6f2f0ee45219ceead7105607cd444f5ad10dd51356436095a12019ceead7105607cd444f5ad10dd51356436095a10000000000000000000000000000000000d683bd37f90001c1cba3fcea344f92d9239c08c0568f6f2f0ee45200020701347644bec69a070173c577b48eb8028f5c00016877b1b0c6267e0ad9aa4c0df18a547aa2f6b08d0001744d441ed6a00d59ea1e3fdbad2b10d9a869c92f0001b7ea94340e65cc68d1274ae483dfbe593fd6f21e0000000003010203003401010001020080000343ff00000000000000000000000000000000744d441ed6a00d59ea1e3fdbad2b10d9a869c92fc1cba3fcea344f92d9239c08c0568f6f2f0ee45200000000000000000000000000000000000000000000000040054200000000000000000000000000000000000006bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb300213874200000000000000000000000000000000000006c1cba3fcea344f92d9239c08c0568f6f2f0ee4524a11590e5326138b514e08a9b52202d42077ca6546415998764c29ab2a25cbea6254146d50d2268700000000000000000d1d507e40be80000000ffffffffffffffffffffffffffffbada9c382165b31419f4cc0edf0fa84f80a3c8e5bbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb000300300313884200000000000000000000000000000000000006c1cba3fcea344f92d9239c08c0568f6f2f0ee4524a11590e5326138b514e08a9b52202d42077ca6546415998764c29ab2a25cbea6254146d50d2268700000000000000000d1d507e40be800000000000000000000001347644bec69ab7ea94340e65cc68d1274ae483dfbe593fd6f21ebbbbbbbbbb9cc5e90e3b3af64bdaf62c37eeffcb40014200000000000000000000000000000000000006bada9c382165b31419f4cc0edf0fa84f80a3c8e5000000000000000000000000000000000040014200000000000000000000000000000000000006bada9c382165b31419f4cc0edf0fa84f80a3c8e50000000000000000000000000000000000";
    }
}

// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2000000000000000000000000000000000000000000000000000000000000001c4e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc2bfa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e
// 0xb2f481d177fb61a2c8b8b27503d3f33b5596c6b7f1dd2246e8d14a6e49487bc23fa8d508ba63b8f460adba12ced111eda5b0a53c9cabb6b052f3e5297586154e1c
