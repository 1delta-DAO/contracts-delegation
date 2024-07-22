// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract PermitTestMantle is DeltaSetup {
    uint256 DEFAULT_IR_MODE = 2; // variable

    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 66585629, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});
        address admin = 0x999999833d965c275A2C102a4Ebf222ca938546f;
        address proxy = 0x9bc92bF848FaF2355c429c54d1edE3e767bDd790;
        address oldModule = 0x34a7B8Dec72577B6815F5210cc9C5A4020eB9eF2;
        upgradeExistingDelta(proxy, admin, oldModule);
    }

    // skipt this one for now
    function test_permit_mantle() external /** address user, uint8 lenderId */ {
        // address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        // vm.prank(user);
        // IFlashAggregator(brokerProxyAddress).deltaCompose(getSwapWithPermit());
    }

    function getSwapWithPermit() internal pure returns (bytes memory data) {
        data = hex"32683696523512636b46a826a7e3d1b0658e8e2e1c00a991ae002a960e63ccb0e5bde83a8c13e51e1cb91a9bc92bf848faf2355c429c54d1ede3e767bdd790000000000000000000000000000000000000000000000001760057840c86870fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1b98d0bd76596980d2fed97e4b2b38fb98f8cc0a967154bbf634e5e33032e3523f75bfddb9fda715e83cf24197e32a730e1734975c27612d5da6a286737a3da8040300000000000000015fcaf79277bf016f0000000000000000000001307efe004209bc4e0d864854c6afb6eb9a9cdf58ac190d0df9020437a6b77f1a8ef09ac96e9cda3ed56f615802d713271078c1b0c915c4faa5fffa6cabf0219da63d7f4cb80003030000000000000000128169373e7a26810000000000000000000000000000009809bc4e0d864854c6afb6eb9a9cdf58ac190d0df90203a81ede3710ea5249fdc1a81bb5664d004300ddb700645be26527e817998a7206475496fde1e68957c5a600006f4c4caed9e97d5a9146944af740a706cffa07d901f4cda86a272531e8640cd7f1a92c01839911b90bb00097f59c79b91877c2b5909e703117beab9b4b5df0d678c1b0c915c4faa5fffa6cabf0219da63d7f4cb80003";
    }
}
