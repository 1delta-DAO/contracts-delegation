// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestMantle is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 67161084, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x9bc92bF848FaF2355c429c54d1edE3e767bDd790;
        address oldModule = 0x6aAb342eF29370B57Bf74e1b7e71b9A018137a20;
        upgradeExistingDelta(proxy, admin, oldModule);
        testQuoter = new TestQuoterMantle();
    }

    // skipt this one for now
    function test_permit_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;

        uint256 amount = 0.00005654e8;
        uint256 quoted = testQuoter.quoteExactInput(
            getQuoteDodoV2(1),
            amount //
        );
        console.log("quoted", quoted);
        vm.prank(user);
        vm.expectRevert();
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    function getQuoteDodoV2(uint8 sellQuote) internal view returns (bytes memory data) {
        return abi.encodePacked(WBTC, DODO, FBTC_WBTC_POOL, sellQuote, FBTC);
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"0091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000160300000000000000000000000016160041cabae6f6ea1ecab08ad02fe02ce9a44f09aebfa20099d39dfbfba9e7eccd813918ffbda10b783ea3b3c600c96de26018a54d51c097160568752c4e3bd6c364ff09";
    }
}
