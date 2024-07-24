// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestPolygon is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 59762489, urlOrAlias: "https://polygon-rpc.com"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4;
        address oldModule = 0x11e676D51e01b90c162a640065d58B30c0F3DA04;
        upgradeExistingDelta(proxy, admin, oldModule);
    }

    // skipt this one for now
    function test_permit_polygon() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(); // should revert with overflow
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"334a1c3ad6ed28a636ee1751c69071f6be75deb8b800e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000006a6faa54b9238f0f079c8e6cba08a7b9776c7fe4000000000000000000000000000000000000000000000001e26870dc6061b1d40000000000000000000000000000000000000000000000000000000066a15ee1000000000000000000000000000000000000000000000000000000000000001b169755e2123080789c0f17667af93de14445d143a9e3948d75d3ad8ff18f10ee1a2b730a6d641d14ddefcaea60d5db40e142fa99040150d1f24da247fe87d38d030000000000000001dda1b42dd68e59e40000000000000000000000000000006ec2132d05d31c914a87c6611c10748aeb04b58e8f0266c2755915a85c6f6c1c0f3a86ac8c058f11caa9c926f27ceb23fd6bc0add59e62ac25578270cff1b9f6190002f1a12338d39fc085d8631e1a745b5116bc9b2a3201f40d500b1d8e8ef31e21c99d1db9a6444d3adf12700002";
    }
}
