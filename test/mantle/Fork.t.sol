// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestMantle is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 66773300, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x9bc92bF848FaF2355c429c54d1edE3e767bDd790;
        address oldModule = 0x6aAb342eF29370B57Bf74e1b7e71b9A018137a20;
        upgradeExistingDelta(proxy, admin, oldModule);
    }

    // skipt this one for now
    function test_permit_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert();
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"32e71cbaaa6b093fce66211e6f218780685077d8b500e000000000000000000000000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000009bc92bf848faf2355c429c54d1ede3e767bdd790000000000000000000000000000000000000000000000000000000000099f9a5ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000001c1f8fbc32d617ef1c45f9a1b38babe9a972f0c56cf3cef7fb4570244a7603951e081fa8bc4abcd9d6880cf43c1518d3481bd037c91c5418bb2e9c46956ac98a853400201eba5cc46d216ce6dc03f6a759e8e766e956ae000000000000000000000098735f01b004201eba5cc46d216ce6dc03f6a759e8e766e956aed9f4e85489adcd0baf0cd63b4231c6af58c26745d9f4e85489adcd0baf0cd63b4231c6af58c26745000000000000000000000098735f00f383bd37f90001201eba5cc46d216ce6dc03f6a759e8e766e956ae000178c1b0c915c4faa5fffa6cabf0219da63d7f4cb80398735f089b46c3d9d2a780000106240001926faafce6148884cd5cf98cd1878f865e8911bf000000019bc92bf848faf2355c429c54d1ede3e767bdd79000000000040102050006010001020102070001030400ff0000000000000000000000000000011d57bb869f6c7a9e69323c3f277720d2919be7201eba5cc46d216ce6dc03f6a759e8e766e956ae98d1e99d294e8603fa050ea129c78388408e0dd1deaddeaddeaddeaddeaddeaddeaddeaddead1111000000000000000000000000000000001078c1b0c915c4faa5fffa6cabf0219da63d7f4cb891ae002a960e63ccb0e5bde83a8c13e51e1cb91a00000000000000000000000000000013201eba5cc46d216ce6dc03f6a759e8e766e956ae9bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000000000000098967e23201eba5cc46d216ce6dc03f6a759e8e766e956ae91ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000000000000000000000";
    }
}
