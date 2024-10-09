// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestMantle is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 70043486, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x9bc92bF848FaF2355c429c54d1edE3e767bDd790;
        address oldModule = 0xCB9FF5D38285CFfd44ba0DA269f26cF8a22baDDB;
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
        vm.prank(user);
        vm.expectRevert();
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

        // skipt this one for now
    function test_generic_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: 0}(
            getSwapDataFull()
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

    function getQuoteDodoV2(uint8 sellQuote) internal view returns (bytes memory data) {
        return abi.encodePacked(WBTC, DODO, FBTC_WBTC_POOL, sellQuote, FBTC);
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"0091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000160300000000000000000000000016160041cabae6f6ea1ecab08ad02fe02ce9a44f09aebfa20099d39dfbfba9e7eccd813918ffbda10b783ea3b3c600c96de26018a54d51c097160568752c4e3bd6c364ff09";
    }


    function getSwapDataFull() internal pure returns (bytes memory data) {
        // this data is incorrect
        //       0x17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b1009bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000001e949f5e6faf1d26000000000000112c2f1d357b974600585be26527e817998a7206475496fde1e68957c5a6003209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007bda9d18fd4bc094660d79721feb2e72c962ab54fe270f78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000001e949f5e6faf1d26000000000000000000000000000000
        data = hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b1009bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000001e949f5e6faf1d26000000000000112c2f1d357b974600585be26527e817998a7206475496fde1e68957c5a6003209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007bda9d18fd4bc094660d79721feb2e72c962ab54fe270f78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000001e949f5e6faf1d26000000000000000000000000000000";
    }
}
