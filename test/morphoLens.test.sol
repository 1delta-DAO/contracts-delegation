// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {MorphoLens} from "../contracts/external-protocols/misc/MorphoLens.sol";

contract MorphoLensTest is Test {
    MorphoLens public morphoLens;
    address public moolah = 0x8F73b65B4caAf64FBA2aF91cC5D4a2A1318E5D8C;
    address public user = 0x07CF7b53F524783858F2739737730D513643F909;
    bytes32 public id1 = 0x2292a4820cdf330b88ba079671484d228db4a07957db9bc24e3f1c0b42c44b84;
    bytes32 public id2 = 0xa6a01504ccb6a0e3832e1fae31cc4f606a7c38cd76071f27befd013b8e46e78e;
    bytes32 public id3 = 0x93e0995138222571035a6deadd617efad2f2400d69067a0d1fc74b179657046a;
    bytes32 public id4 = 0xf3a85dfdf8c44398c49401aa8f4dc3be20bff806b9da2e902d3b379790a312c6;
    bytes32 public id5 = 0x2e865d41371fb021130dc872741c70564d0f5ea4856ff1542163a8b59b0b524d;

    function setUp() public {
        vm.createSelectFork("https://public-bsc-mainnet.fastnode.io");
        morphoLens = new MorphoLens();
    }

    function test_getUserDataCompact() public {
        bytes32[] memory marketIds = new bytes32[](5);
        marketIds[0] = id1;
        marketIds[1] = id2;
        marketIds[2] = id3;
        marketIds[3] = id4;
        marketIds[4] = id5;
        morphoLens.getUserDataCompact(marketIds, user, moolah);

        bytes memory data = morphoLens.getMoolahMarketDataCompact(moolah, marketIds);
        vm.assertEq(data.length, 290 * marketIds.length);
    }
}
