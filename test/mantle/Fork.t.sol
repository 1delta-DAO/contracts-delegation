// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestMantle is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 73160008, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x9bc92bF848FaF2355c429c54d1edE3e767bDd790;
        address oldModule = 0xCB9FF5D38285CFfd44ba0DA269f26cF8a22baDDB; // 0x74E95F3Ec71372756a01eB9317864e3fdde1AC53;
        upgradeExistingDelta(proxy, admin, oldModule);
        quoter = new OneDeltaQuoter();
    }

    // skipt this one for now
    function test_permit_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;

        uint256 amount = 0.00005654e8;
        uint256 quoted = quoter.quoteExactInput(
            getQuoteDodoV2(1),
            amount //
        );
        console.log("quoted", quoted);
        vm.prank(user);
        vm.expectRevert();
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    // skipt this one for now
    function test_permit_mantle_1() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;

        // uint256 amount = 512911465942882;
        vm.expectRevert();
        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit1());
    }

    // skipt this one for now
    function test_generic_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: 0}(getSwapDataFull());
        vm.expectRevert();
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

    // skipt this one for now
    function test_generic_qa_mantle() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: 0}(getSwapDataFull());
        vm.expectRevert();
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

    function getQuoteDodoV2(uint8 sellQuote) internal pure returns (bytes memory data) {
        return abi.encodePacked(TokensMantle.WBTC, DexMappingsMantle.DODO, FBTC_WBTC_POOL, sellQuote, TokensMantle.FBTC);
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"0091ae002a960e63ccb0e5bde83a8c13e51e1cb91a0000000000000000000000000000160300000000000000000000000016160041cabae6f6ea1ecab08ad02fe02ce9a44f09aebfa20099d39dfbfba9e7eccd813918ffbda10b783ea3b3c600c96de26018a54d51c097160568752c4e3bd6c364ff09";
    }

    function getSwapWithPermit1() internal pure returns (bytes memory data) {
        // this data is incorrect
        data = hex"32cda86a272531e8640cd7f1a92c01839911b90bb000640000000000000000000000000000000000000000000000000001d27d81ba8f6277359400cd4e75a255952274ba2cef5e2fb4b585d174f746d0b65bc531ab24908ea5ad581d79d4ac9030a8bb1441a29b65b340a35012840e9a70693e5061e3ecbe890d91";
    }

    function getSwapDataFull() internal pure returns (bytes memory data) {
        // this data is incorrect
        //       0x17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b1009bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000001e949f5e6faf1d26000000000000112c2f1d357b974600585be26527e817998a7206475496fde1e68957c5a6003209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007bda9d18fd4bc094660d79721feb2e72c962ab54fe270f78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000001e949f5e6faf1d26000000000000000000000000000000
        data = hex"17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b1009bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000001e949f5e6faf1d26000000000000112c2f1d357b974600585be26527e817998a7206475496fde1e68957c5a6003209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007bda9d18fd4bc094660d79721feb2e72c962ab54fe270f78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000001e949f5e6faf1d26000000000000000000000000000000";
    }

    function getQASwapDataFull() internal pure returns (bytes memory data) {
        // this data is incorrect
        //       0x17d73091000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000b1009bc92bf848faf2355c429c54d1ede3e767bdd79000000000000000001e949f5e6faf1d26000000000000112c2f1d357b974600585be26527e817998a7206475496fde1e68957c5a6003209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9007bda9d18fd4bc094660d79721feb2e72c962ab54fe270f78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8ff092491ae002a960e63ccb0e5bde83a8c13e51e1cb91a000000000000001e949f5e6faf1d26000000000000000000000000000000
        data = hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000017e328e3f5e745a030a384fbd19c97a56da5337147376006400000000000000000000000000000000000000000000000004f46e02f4f256fb6761ab554ebc772493c5c3088530c0f609b16527d5bf9aa8a37c93267616a64429f6ee340099213d20789bb46f72960bc1554a1a0c52a3361c26a4965b10618c7c787be313211cc4dd073734da055fbf44a2b4667d5e5fe5d29bc92bf848faf2355c429c54d1ede3e767bdd79000ffffffffffffffffffffffffffff0091ae002a960e63ccb0e5bde83a8c13e51e1cb91a800000000000000005442c07798d1ec600000000000004f46e02f4f256fb0096211cc4dd073734da055fbf44a2b4667d5e5fe5d20097e50019c79cbd7c49cffa7c3f8080ea238de759625d3a1ff2b6bab83b63cd9ad0787074081a52ef3400982e488d7ed78171793fa91fad5352be423a50dae178c1b0c915c4faa5fffa6cabf0219da63d7f4cb80003e0d80d6377aadcb0a648cc157f593c60390385e727105be26527e817998a7206475496fde1e68957c5a6ff090000";
    }

    // 0x32cda86a272531e8640cd7f1a92c01839911b90bb000640000000000000000000000000000000000000000000000000001d27d81ba8f6277359400cd4e75a255952274ba2cef5e2fb4b585d174f746d0b65bc531ab24908ea5ad581d79d4ac9030a8bb1441a29b65b340a35012840e9a70693e5061e3ecbe890d91
}
