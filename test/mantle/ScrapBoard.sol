// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./utils/FlashLoanCaller.sol";
import "./DeltaSetup.f.sol";

/**
 * We test flash swap executions using exact in trade types (given that the first pool supports flash swaps)
 * These are always applied on margin, however, we make sure that we always get
 * The expected amounts. Exact out swaps always execute flash swaps whenever possible.
 */
contract FlashLoanTest is DeltaSetup {
    function testFlashLoan() external {
        FCaller caller = new FCaller();
        address receiver = 0x1E5e3b014C8E307E5849371660dCd05764A2207d;
        address obf = 0xeaEE7EE68874218c3558b40063c42B82D3E7232a;
        address[] memory assets = new address[](1);
        assets[0] = WMNT;
        uint256[] memory amounts = new uint256[](1);
        uint256 amount = 11111111111111111;
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 6;
        bytes memory params = abi.encodePacked("hello");
        console.logBytes(params);
        uint16 referralCode = 9999;
        console.log("test fl", address(this), params.length);
        console.logBytes(
            abi.encodeWithSelector(
                IFL.flashLoan.selector,
                receiver,
                assets,
                amounts,
                modes,
                obf,
                params,
                referralCode //
            )
        );
        // IFL(address(caller)).flashLoan(
        //     receiver,
        //     assets,
        //     amounts,
        //     modes,
        //     obf,
        //     params,
        //     referralCode //
        // );
        console.log("test callFlash");
        caller.callFlash(
            address(caller),
            receiver,
            obf,
            modes[0],
            WMNT,
            uint112(amount),
            referralCode,
            params //
        );
    }

    // 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 0xab9c4b5d
    // 0x0000000000000000000000001e5e3b014c8e307e5849371660dcd05764a2207d
    // 0x00000000000000000000000000000000000000000000000000000000000000e0
    // 0x0000000000000000000000000000000000000000000000000000000000000120
    // 0x0000000000000000000000000000000000000000000000000000000000000160
    // 0x000000000000000000000000eaee7ee68874218c3558b40063c42b82d3e7232a
    // 0x00000000000000000000000000000000000000000000000000000000000001a0
    // 0x000000000000000000000000000000000000000000000000000000000000270f
    // 0x0000000000000000000000000000000000000000000000000000000000000001
    // 0x00000000000000000000000078c1b0c915c4faa5fffa6cabf0219da63d7f4cb8
    // 0x0000000000000000000000000000000000000000000000000000000000000001
    // 0x0000000000000000000000000000000000000000000000000027797f26d671c7
    // 0x0000000000000000000000000000000000000000000000000000000000000001
    // 0x0000000000000000000000000000000000000000000000000000000000000006
    // 0x0000000000000000000000000000000000000000000000000000000000000005
    // 0x68656c6c6f000000000000000000000000000000000000000000000000000000
    function testArr() external {
        FCaller caller = new FCaller();
        address[] memory assets = new address[](1);
        assets[0] = WMNT;
        caller.arr(assets);
        console.log("test arr");
        caller.callArr();
    }

    function testArr2() external {
        print();
        FCaller caller = new FCaller();
        address[] memory assets = new address[](1);
        assets[0] = WMNT;
        caller.arr2(assets, assets);
        console.log("test arr");
        uint s = 32;
        uint t = 32;
        for (uint i; i < 10; i++) {
            for (uint j; j < 10; j++) {
                caller.callArr2(s, t);
                t += 32;
                console.log("s,t", s, t);
            }
            s += 32;
        }
    }

    function print() internal view {
        uint i;
        while (true) {
            console.log("index", i, i * 32 + 4);
            i++;
            if (i > 20) break;
        }
    }
}
