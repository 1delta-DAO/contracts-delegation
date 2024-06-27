// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./utils/FlashLoanCaller.sol";
import "./DeltaSetup.f.sol";

/**
 * We test flash swap executions using exact in trade types (given that the first pool supports flash swaps)
 * These are always applied on margin, however, we make sure that we always get
 * The expected amounts. Exact out swaps always execute flash swaps whenever possible.
 */
contract FlashLoanTestPolygon is DeltaSetup {
    function testFlashLoan_polygon() external {
        FCaller caller = new FCaller();
        address receiver = 0x1E5e3b014C8E307E5849371660dCd05764A2207d;
        address[] memory assets = new address[](1);
        assets[0] = WMATIC;
        uint256[] memory amounts = new uint256[](1);
        uint256 amount = 11111111111111111;
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 6;
        bytes memory params = abi.encodePacked("hello");
        console.logBytes(params);
        console.log("test fl", address(this), params.length);
        console.logBytes(
            abi.encodeWithSelector(
                IAllFlashLoans.flashLoan.selector,
                receiver,
                assets,
                amounts,
                params //
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
            WMATIC,
            uint112(amount),
            params //
        );
    }

    // 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
    // 0x5c38449e
    // 0x0000000000000000000000001e5e3b014c8e307e5849371660dcd05764a2207d
    // 0x0000000000000000000000000000000000000000000000000000000000000080
    // 0x00000000000000000000000000000000000000000000000000000000000000c0
    // 0x0000000000000000000000000000000000000000000000000000000000000100
    // 0x0000000000000000000000000000000000000000000000000000000000000001
    // 0x0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270
    // 0x0000000000000000000000000000000000000000000000000000000000000001
    // 0x0000000000000000000000000000000000000000000000000027797f26d671c7
    // 0x0000000000000000000000000000000000000000000000000000000000000005
    // 0x68656c6c6f000000000000000000000000000000000000000000000000000000

    function testAaveFlashLoan_polygon() external {
        FCaller caller = new FCaller();
        address receiver = 0x1E5e3b014C8E307E5849371660dCd05764A2207d;
        uint256 amount = 11111111111111111;
        bytes memory params = abi.encodePacked("hello");
        console.logBytes(params);
        uint16 refC = 12324;
        console.log("test fl", address(this), params.length);
        console.logBytes(
            abi.encodeWithSelector(
                IAllFlashLoans.flashLoanSimple.selector,
                receiver,
                WMATIC,
                amount,
                params, //
                refC
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
        caller.callFlashAave(
            address(caller),
            receiver,
            WMATIC,
            uint112(amount),
            refC,
            params //
        );
    }

    // 0x42b0b77c
    // 0000000000
    // 0x0000000000000000000000001e5e3b014c8e307e5849371660dcd05764a2207d
    // 0x0000000000000000000000000d500b1d8e8ef31e21c99d1db9a6444d3adf1270
    // 0x0000000000000000000000000000000000000000000000000027797f26d671c7
    // 0x00000000000000000000000000000000000000000000000000000000000000a0
    // 0x0000000000000000000000000000000000000000000000000000000000003024
    // 0x0000000000000000000000000000000000000000000000000000000000000005
    // 0x68656c6c6f000000000000000000000000000000000000000000000000000000
    // 0x68656c6c6f0000000000000000000000000000000000000000000000000000000000000000


    function testArr() external {
        FCaller caller = new FCaller();
        address[] memory assets = new address[](1);
        assets[0] = WMATIC;
        caller.arr(assets);
        console.log("test arr");
        caller.callArr();
    }

    function testArr2() external {
        print();
        FCaller caller = new FCaller();
        address[] memory assets = new address[](1);
        assets[0] = WMATIC;
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
