// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./DeltaSetup.f.sol";

contract Debug is DeltaSetup {
    function setUp() public virtual override {
        vm.createSelectFork({blockNumber: 65602486, urlOrAlias: "https://mantle-mainnet.public.blastapi.io"});

        deployDelta();
        initializeDelta();
    }

    function test_debug() external {
        address user = 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A;
        vm.assume(user != address(0));
        address assetIn = WMNT;
        address assetOut = USDC;

        uint256 amountIn = 50000000000000000000;
        vm.deal(user, amountIn);

        bytes memory data = getCalldata();
        bytes memory test = sweep(USDC, 0x91ae002a960e63Ccb0E5bDE83A8C13E51e1cB91A, 0, SweepType.VALIDATE);
        console.logBytes(test);
        vm.prank(user);
        IERC20All(assetIn).approve(brokerProxyAddress, amountIn);

        uint256 balanceIn = user.balance;
        uint256 balanceOut = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        IFlashAggregator(brokerProxyAddress).deltaCompose{value: amountIn}(data);

        balanceOut = IERC20All(assetOut).balanceOf(user) - balanceOut;
        balanceIn = balanceIn - user.balance;

        // swap 10, receive approx 10, but in 18 decs
        assertApproxEqAbs(38495951, balanceOut, 1);
        assertApproxEqAbs(balanceIn, amountIn, 0);
    }

    /** KTX PATH BUILDERS */

    function getCalldata() internal pure returns (bytes memory data) {
        data = hex"23000000000002b5e3af16b18800000091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000001cc0b670000000000022b1c8c1227a00000004278c1b0c915c4faa5fffa6cabf0219da63d7f4cb8000437a6b77f1a8ef09ac96e9cda3ed56f615802d713271009bc4e0d864854c6afb6eb9a9cdf58ac190d0df9ff090091ae002a960e63ccb0e5bde83a8c13e51e1cb91a80000000000000000000000000730fa00000000000008ac7230489e80000004278c1b0c915c4faa5fffa6cabf0219da63d7f4cb800011858d52cf57c07a018171d7a1e68dc081f17144f01f409bc4e0d864854c6afb6eb9a9cdf58ac190d0df9ff09";
    }
}
