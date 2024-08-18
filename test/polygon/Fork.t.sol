// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestPolygon is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 60749379, urlOrAlias: "https://polygon.api.onfinality.io/public"});
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
        vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: 5000000000000000000}(abi.encodeWithSelector(IFlashAggregator.deltaCompose.selector, getGenericData()));
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
        data = hex"030000000000000000000d71b37da59ad90000000000000000000000989f3900422791bca1f2de4661ed88a30c99a7a9449aa8417402677d51bad48d253dae37cc82cad07f73849286deec26f27ceb23fd6bc0add59e62ac25578270cff1b9f61932030300000000000000000049fbd43ce89d4c0000000000000000000003476bbd006e2791bca1f2de4661ed88a30c99a7a9449aa841740203ae81fac689a1b4b1e06e7ef4a2ab4cd8ac0a087d033c0d500b1d8e8ef31e21c99d1db9a6444d3adf1270000086f1d8390222a3691c28938ec7404a1661e618e001f47ceb23fd6bc0add59e62ac25578270cff1b9f6193203030000000000000000002856b80567980e0000000000000000000001c9ddad00422791bca1f2de4661ed88a30c99a7a9449aa841740201ce67850420c82db45eb7feeccd2d181300d2bdb301f47ceb23fd6bc0add59e62ac25578270cff1b9f61932030300000000000000000006b8d00afd40f80000000000000000000000000000006e2791bca1f2de4661ed88a30c99a7a9449aa841740203e7e0eb9f6bcccfe847fdf62a3628319a092f11a2e6958f3cf7ad23cd3cadbd9735aff958023239c6a06300006bad0f9a89ca403bb91d253d385cec1a2b6eca970bb87ceb23fd6bc0add59e62ac25578270cff1b9f6193203";
    }

    function getGenericData() internal pure returns (bytes memory data) {
        // this data is incorrect for block 60576346
        data = hex"230000000000004563918244f400000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000011a3560000000000002629f66e0c53000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700087380615f37993b5a96adf3d443b6e0ac50a211998270b2791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000000000000000199c200000000000003782dace9d9000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700069019011032a7ac3a87ee885b6c08467ac46ad11cd26fc2791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000099c7600000000000014d1120d7b16000000980d500b1d8e8ef31e21c99d1db9a6444d3adf12700064711b6f6788e4cb0f7034bf02b149118a46e500c226f27ceb23fd6bc0add59e62ac25578270cff1b9f6190078c427ec5934c33e67ccca070ed3f65abf31c64607270b1bfd67037b42cf73acf2047067bd4f2c47d9bfd60096ed9e3f98bbed560e66b89aac922e29d4596a96422791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000000000000000199d300000000000003782dace9d9000000420d500b1d8e8ef31e21c99d1db9a6444d3adf12700002934f3f8749164111f0386ece4f4965a687e576d500642791bca1f2de4661ed88a30c99a7a9449aa84174ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000019a2900000000000003782dace9d90000006e0d500b1d8e8ef31e21c99d1db9a6444d3adf127000007a7374873de28b06386013da94cbd9b554f6ac6e00648f3cf7ad23cd3cadbd9735aff958023239c6a0630003e7e0eb9f6bcccfe847fdf62a3628319a092f11a2cf432791bca1f2de4661ed88a30c99a7a9449aa84174ff09";
    }
}
