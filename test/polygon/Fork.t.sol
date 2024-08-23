// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestPolygon is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 60825008, urlOrAlias: "https://polygon.api.onfinality.io/public"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4;
        address oldModule = 0x5F82874a9e2bf4509FcE3b845a3862897eff276a;
        upgradeExistingDelta(proxy, admin, oldModule);
    }

    // skipt this one for now
    function test_permit_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(); // should revert with overflow
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    // skipt this one for now
    function test_generic_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: 5000000000000000000}(
            abi.encodeWithSelector(IFlashAggregator.deltaCompose.selector, getGenericData())
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

    function getGenericData() internal pure returns (bytes memory data) {
        // this data is incorrect for block 60576346
        data = hex"230000000000004563918244f400000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000011a3560000000000002629f66e0c53000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700087380615f37993b5a96adf3d443b6e0ac50a211998270b2791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000000000000000199c200000000000003782dace9d9000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700069019011032a7ac3a87ee885b6c08467ac46ad11cd26fc2791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000099c7600000000000014d1120d7b16000000980d500b1d8e8ef31e21c99d1db9a6444d3adf12700064711b6f6788e4cb0f7034bf02b149118a46e500c226f27ceb23fd6bc0add59e62ac25578270cff1b9f6190078c427ec5934c33e67ccca070ed3f65abf31c64607270b1bfd67037b42cf73acf2047067bd4f2c47d9bfd60096ed9e3f98bbed560e66b89aac922e29d4596a96422791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000000000000000199d300000000000003782dace9d9000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700002934f3f8749164111f0386ece4f4965a687e576d500642791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000019a2900000000000003782dace9d90000006e0d500b1d8e8ef31e21c99d1db9a6444d3adf127000007a7374873de28b06386013da94cbd9b554f6ac6e00648f3cf7ad23cd3cadbd9735aff958023239c6a0630003e7e0eb9f6bcccfe847fdf62a3628319a092f11a2cf432791bca1f2de4661ed88a30c99a7a9449aa84174ff09";
    }
}
