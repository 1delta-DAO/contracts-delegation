// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestTaiko is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 761510, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        // address proxy = 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2;
        address oldModule = 0xbaEe36c9ef69b0F8454e379314c7CBA628Fc6B61;
        address proxy = 0x164e08ACE9DAe58BEa18eF268b716f5deBD7c692;
        // address proxy = 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2;
        // address oldModule = 0x5c4F2eACBdc1EB38F839bDDD7620E250a36819D4;
        upgradeExistingDelta(proxy, admin, oldModule);
        testQuoter = new PoolGetter();
    }

    function test_generic_taiko() external /** address user, uint8 lenderId */ {
        address user = 0x55D554BfdE1E61c72fa3C9059cDf3f739d92679a;
        vm.prank(user);
        (bytes memory data, uint value) = getSwap();
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: value}( //
            data //
        );
        vm.expectRevert(); // should revert "K", bug in KODO
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

    function test_compose_taiko() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert(); // should revert "K", bug in KODO
        (bytes memory data, uint value) = getSwapWithPermit();
        IFlashAggregator(address(brokerProxyAddress)).deltaCompose{value: value}( //
            data //
        );
    }

    function test_open_taiko_tako() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        // vm.expectRevert(); // should revert "K", bug in KODO
        bytes memory data = getOpen();
        (bool success, bytes memory ret) = address(brokerProxyAddress).call( //
            data //
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

    // calldata, v 0x23000000000000002386f26fc100000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000012ca350000000000000001c6bf52634000009aa51894664a773981c6c112c43ce576f315d5b1b60087349b458e831e5334fb2a46a9f0ce21e5a2098e74270ea9d23408b9ba935c230493c40c73824df71a0975007846de41513f889bf6344a6ba39ecad7344b359fbd26fc2def195713cf4a606b49d07e520e22c17899a7360087a6b01b0e04acc62aba14c02afc0e4c59dab7c05a270e07d83526730c7438048d55a4fc0b850e2aab6f0bff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000164b77e0000000000000021c0331d5dc0000042a51894664a773981c6c112c43ce576f315d5b1b60000e47a76e15a6f3976c8dc070b3a54c7f7083d668b01f407d83526730c7438048d55a4fc0b850e2aab6f0bff09 10000000000000000

    function getSwapWithPermit() internal pure returns (bytes memory data, uint value) {
        // this data is incorrect
        data = hex"23000000000000002386f26fc100000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000012ca350000000000000001c6bf52634000009aa51894664a773981c6c112c43ce576f315d5b1b60087349b458e831e5334fb2a46a9f0ce21e5a2098e74270ea9d23408b9ba935c230493c40c73824df71a0975007846de41513f889bf6344a6ba39ecad7344b359fbd26fc2def195713cf4a606b49d07e520e22c17899a7360087a6b01b0e04acc62aba14c02afc0e4c59dab7c05a270e07d83526730c7438048d55a4fc0b850e2aab6f0bff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000164b77e0000000000000021c0331d5dc0000042a51894664a773981c6c112c43ce576f315d5b1b60000e47a76e15a6f3976c8dc070b3a54c7f7083d668b01f407d83526730c7438048d55a4fc0b850e2aab6f0bff09";
        value = 10000000000000000;
    }

    function getSwap() internal pure returns (bytes memory data, uint value) {
        // this data is incorrect
        data = hex"17d730910000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000023b32a9d23408b9ba935c230493c40c73824df71a097500e000000000000000000000000055d554bfde1e61c72fa3c9059cdf3f739d92679a0000000000000000000000000bd7473cbbf81d9dd936c61117ed230d95006ca2000000000000000000000000000000000000000000000005f68e8131ecf800000000000000000000000000000000000000000000000000000000000066ec8d03000000000000000000000000000000000000000000000000000000000000001cd909228fcef6f4ec99f99fac3cda43fcaac18ab5763618e7737c0b2fc8909fbc1d07910ec033bc42c7790e1cc445de25155eea83176a773eef28e1eee259958e0055d554bfde1e61c72fa3c9059cdf3f739d92679a0000000000000000000000000a27e9830000000000051192ba9da30600000042a9d23408b9ba935c230493c40c73824df71a09750000dac937d4263e6a667a027fe59b2ffe2f91d54f46271007d83526730c7438048d55a4fc0b850e2aab6f0bff090055d554bfde1e61c72fa3c9059cdf3f739d92679a00000000000000000000000001cbd803000000000000e4fbc69449f200000098a9d23408b9ba935c230493c40c73824df71a09750078977343dc3086cb2c6a7c17833020fe4553ff0cf026fca51894664a773981c6c112c43ce576f315d5b1b60031ce82a83a3cd0c1a376818fb910c1cfd185e1bbfe0bb819e26b0638bf63aa9fa4d14c6baf8d52ebe86c5c00966c7839e0ce8ada360a865e18a111a462d08dc15a07d83526730c7438048d55a4fc0b850e2aab6f0bff090000000000";
        value = 0;
    }

    function getOpen() internal pure returns (bytes memory data) {
        data = hex"17d7309100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000064020000000000000000000367321ab58b3700000000000000000000002dc6c0004307d83526730c7438048d55a4fc0b850e2aab6f0b030512c1faa6195b8a81140deaf9c25b8f15237be82900c3a51894664a773981c6c112c43ce576f315d5b1b603e90200000000000000000000000000000000000000000000000000000000";
    }
}
