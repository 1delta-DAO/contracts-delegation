// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract ForkTestTaiko is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 334208, urlOrAlias: "https://rpc.mainnet.taiko.xyz"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2;
        address oldModule = 0x5c4F2eACBdc1EB38F839bDDD7620E250a36819D4;
        upgradeExistingDelta(proxy, admin, oldModule);
        testQuoter = new TestQuoterTaiko();
    }

    function test_generic_taiko() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert(0x7dd37f70); // should revert with slippage
        (bytes memory data, uint value) = getSwapWithPermit();
        (bool success, bytes memory ret) = address(brokerProxyAddress).call{value: value}( //
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

    function test_compose_taiko() external /** address user, uint8 lenderId */ {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.prank(user);
        vm.expectRevert(); // should revert "K", bug in KODO
        (bytes memory data, uint value) = getSwapWithPermit();
        IFlashAggregator(address(brokerProxyAddress)).deltaCompose{value: value}( //
            data //
        );
    
    }

    // calldata, v 0x23000000000000002386f26fc100000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000012ca350000000000000001c6bf52634000009aa51894664a773981c6c112c43ce576f315d5b1b60087349b458e831e5334fb2a46a9f0ce21e5a2098e74270ea9d23408b9ba935c230493c40c73824df71a0975007846de41513f889bf6344a6ba39ecad7344b359fbd26fc2def195713cf4a606b49d07e520e22c17899a7360087a6b01b0e04acc62aba14c02afc0e4c59dab7c05a270e07d83526730c7438048d55a4fc0b850e2aab6f0bff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000164b77e0000000000000021c0331d5dc0000042a51894664a773981c6c112c43ce576f315d5b1b60000e47a76e15a6f3976c8dc070b3a54c7f7083d668b01f407d83526730c7438048d55a4fc0b850e2aab6f0bff09 10000000000000000

    function getSwapWithPermit() internal pure returns (bytes memory data, uint value) {
        // this data is incorrect
        data = hex"23000000000000002386f26fc100000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000012ca350000000000000001c6bf52634000009aa51894664a773981c6c112c43ce576f315d5b1b60087349b458e831e5334fb2a46a9f0ce21e5a2098e74270ea9d23408b9ba935c230493c40c73824df71a0975007846de41513f889bf6344a6ba39ecad7344b359fbd26fc2def195713cf4a606b49d07e520e22c17899a7360087a6b01b0e04acc62aba14c02afc0e4c59dab7c05a270e07d83526730c7438048d55a4fc0b850e2aab6f0bff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a8000000000000000000000000164b77e0000000000000021c0331d5dc0000042a51894664a773981c6c112c43ce576f315d5b1b60000e47a76e15a6f3976c8dc070b3a54c7f7083d668b01f407d83526730c7438048d55a4fc0b850e2aab6f0bff09";
        value = 10000000000000000;
    }
}
