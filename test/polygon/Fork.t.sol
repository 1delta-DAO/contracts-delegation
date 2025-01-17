// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

// solhint-disable max-line-length

contract ForkTestPolygon is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 66030114, urlOrAlias: "https://polygon.api.onfinality.io/public"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4;
        address oldModule = 0x1bD60a4b301C28A03501a1A5F909890489EF616B;
        upgradeExistingDelta(proxy, admin, oldModule);
    }

    // skipt this one for now
    function test_permit_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.expectRevert();
        vm.prank(user);
        // vm.expectRevert(); // should revert with overflow
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    // skipt this one for now
    function test_repay_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;

        (bytes memory d , uint v) = getTxData();
        vm.prank(user);
        vm.expectRevert(); // should revert with overflow
        IFlashAggregator(brokerProxyAddress).deltaCompose{value:v}(d);
    }

    // skipt this one for now
    function test_generic_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert(); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call(
            getGenericData()
        );
        if (!success) {
            console.logBytes(ret);
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (ret.length < 68) revert();
            assembly {
                ret := add(ret, 0x04)
            }
            revert(abi.decode(ret, (string)));
        }
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is correct for bloclk 59909525
        data = hex"32078f358208685046a11c85e8ad32895ded33a24900e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000006a6faa54b9238f0f079c8e6cba08a7b9776c7fe4000000000000000000000000000000000000000000000000000000000001c0db0000000000000000000000000000000000000000000000000000000066c4c04d000000000000000000000000000000000000000000000000000000000000001cee0f1afa1226f7f07558ef1cb8c22079480dec911ecf60ce505d8907691435a453c7babb3fdca39e8be30d709cef3c75fda3741d25a1d184396db19a3abdae9802000000000000000000583aa0cfbc8f58000000000000000000000000000000421bfd67037b42cf73acf2047067bd4f2c47d9bfd6030050eaedb835021e4a108b7290636d62e9765cc6d701f47ceb23fd6bc0add59e62ac25578270cff1b9f6190003";
    }

    function getTxData() internal pure returns (bytes memory data, uint value) {
        // this data is correct for bloclk 59909525
        data = hex"23000000000000013fe7fdfbcfd381120d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0002ffffffffffffffffffffffffffff220d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000";
    value = 90045595608142721;
    }

    function getGenericData() internal pure returns (bytes memory data) {
        // this data is incorrect for block 60576346
        data = hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000034d33fccf3cabbe80101232d343252614b6a3ee81c98900e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000006a6faa54b9238f0f079c8e6cba08a7b9776c7fe40000000000000000000000000000000000000000000000000000000000b8cea10000000000000000000000000000000000000000000000000000000067537bb2000000000000000000000000000000000000000000000000000000000000001b9214cb4960304fb4a87269163541971c502fb1a4b5827910ad236d32c89207c25e61fe8b2ca2d7ebdbbaaf42d624ead85cd5a1fef3fec13dc2858fcf3d4d3ee034002791bca1f2de4661ed88a30c99a7a9449aa841740000000000000000000000b6fa350230042791bca1f2de4661ed88a30c99a7a9449aa841744e3288c9ca110bcc82bf38f09a7b425c095d92bf4e3288c9ca110bcc82bf38f09a7b425c095d92bf0000000000000000000000b6fa35017283bd37f900012791bca1f2de4661ed88a30c99a7a9449aa8417400017ceb23fd6bc0add59e62ac25578270cff1b9f61903b6fa35070a84ab91955b1200c49b00018D3D65F675f096dB9f27fc4162757A5162EF103A000000016A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4000000000802040a0138c49d06030102010203011e014055da85030200010403001e00200306030606030001000506010f020300010001070118040f0001080901ff0000007fec4bfcadabf3a811792d568743842fb571b6730df9e46c0eaedf41b9d4bbe2cea2af6e8181b0332791bca1f2de4661ed88a30c99a7a9449aa84174e15e9d2a5af5c1d3524bbc594ddc4a7d80ad27cd6d3842ab227a0436a6e8c459e93c74bd8c16fb341bfd67037b42cf73acf2047067bd4f2c47d9bfd63a3df212b7aa91aa0402b9035b098891d276572b0312692e9cadd3ddaace2e112a4e36397bd2f18a0b3f868e0be5597d5db7feb59e1cadbb0fdda50a000000000000000000000000107ceb23fd6bc0add59e62ac25578270cff1b9f61991ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000112791bca1f2de4661ed88a30c99a7a9449aa841746a6faa54b9238f0f079c8e6cba08a7b9776c7fe400020000000000000000000000b711a000000000000000000000000000000000000000";
    }
}
// 0x23000000000000013fe7fdfbcfd381120d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0002ffffffffffffffffffffffffffff220d500b1d8e8ef31e21c99d1db9a6444d3adf127091ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000 
// 90045595608142721
// 65168370
// 0x17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000034d33fccf3cabbe80101232d343252614b6a3ee81c98900e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000006a6faa54b9238f0f079c8e6cba08a7b9776c7fe40000000000000000000000000000000000000000000000000000000000b8cea10000000000000000000000000000000000000000000000000000000067537bb2000000000000000000000000000000000000000000000000000000000000001b9214cb4960304fb4a87269163541971c502fb1a4b5827910ad236d32c89207c25e61fe8b2ca2d7ebdbbaaf42d624ead85cd5a1fef3fec13dc2858fcf3d4d3ee034002791bca1f2de4661ed88a30c99a7a9449aa841740000000000000000000000b6fa350230042791bca1f2de4661ed88a30c99a7a9449aa841744e3288c9ca110bcc82bf38f09a7b425c095d92bf4e3288c9ca110bcc82bf38f09a7b425c095d92bf0000000000000000000000b6fa35017283bd37f900012791bca1f2de4661ed88a30c99a7a9449aa8417400017ceb23fd6bc0add59e62ac25578270cff1b9f61903b6fa35070a84ab91955b1200c49b00018D3D65F675f096dB9f27fc4162757A5162EF103A000000016A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4000000000802040a0138c49d06030102010203011e014055da85030200010403001e00200306030606030001000506010f020300010001070118040f0001080901ff0000007fec4bfcadabf3a811792d568743842fb571b6730df9e46c0eaedf41b9d4bbe2cea2af6e8181b0332791bca1f2de4661ed88a30c99a7a9449aa84174e15e9d2a5af5c1d3524bbc594ddc4a7d80ad27cd6d3842ab227a0436a6e8c459e93c74bd8c16fb341bfd67037b42cf73acf2047067bd4f2c47d9bfd63a3df212b7aa91aa0402b9035b098891d276572b0312692e9cadd3ddaace2e112a4e36397bd2f18a0b3f868e0be5597d5db7feb59e1cadbb0fdda50a000000000000000000000000107ceb23fd6bc0add59e62ac25578270cff1b9f61991ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000112791bca1f2de4661ed88a30c99a7a9449aa841746a6faa54b9238f0f079c8e6cba08a7b9776c7fe400020000000000000000000000b711a000000000000000000000000000000000000000