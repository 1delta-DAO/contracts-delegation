// SPDX-License-Identifier: BUSL-1.1

import {console} from "forge-std/console.sol";

pragma solidity 0.8.26;

interface IFL {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract FCaller {
    function callFlash(
        address target,
        address receiver,
        address obf,
        uint mode,
        address asset,
        uint112 amount,
        uint16 ref,
        bytes calldata data //
    ) external {
        assembly {
            let ptr := mload(0x40)
            // flashLoan(...)
            mstore(ptr, 0xab9c4b5d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), receiver)
            mstore(add(ptr, 36), 0x0e0) // offset assets
            mstore(add(ptr, 68), 0x120) // offset amounts
            mstore(add(ptr, 100), 0x160) // offset modes
            mstore(add(ptr, 132), obf) // onBefhalfOf
            mstore(add(ptr, 164), 0x1a0) // offset calldata
            mstore(add(ptr, 196), ref) // referral code
            mstore(add(ptr, 228), 1) // length assets
            mstore(add(ptr, 260), asset) // assets[0]
            mstore(add(ptr, 292), 1) // length amounts
            mstore(add(ptr, 324), amount) // amounts[0]
            mstore(add(ptr, 356), 1) // length modes
            mstore(add(ptr, 388), mode) // mode
            mstore(add(ptr, 420), data.length) // length calldata
            calldatacopy(add(ptr, 452), data.offset, data.length) // calldata
            if iszero(
                call(
                    gas(),
                    address(),
                    0x0,
                    ptr,
                    add(data.length, 484), // = 14 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external {
        console.log("enter flash loan");
        uint offs;
        assembly {
            offs := params.offset
        }
        console.log("test", offs);
    }

    function arr(address[] calldata assets) external {
        console.log("enter assets", assets[0]);
        uint offs;
        assembly {
            offs := assets.offset
        }
        console.log("test", offs);
    }

    function callArr() external {
        bytes4 sel = this.arr.selector;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, sel)
            mstore(add(ptr, 4), 32)
            mstore(add(ptr, 36), 1)
            mstore(add(ptr, 68), address())
            if iszero(call(gas(), address(), 0, ptr, 100, ptr, 0x0)) {
                revert(0, 0)
            }
        }
    }

    function arr2(address[] calldata assets, address[] calldata assets1) external {
        console.log("enter assets2----", assets[0]);
        uint offs;
        uint offs2;
        assembly {
            offs := assets.offset
            offs2 := assets1.offset
        }
        console.log("test", offs, offs2);
    }

    function callArr2(uint256 offs1, uint256 offs2) external {
        bytes4 sel = this.arr2.selector;
        bool fail;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, sel)
            mstore(add(ptr, 4), offs1)
            mstore(add(ptr, 36), 1)
            mstore(add(ptr, 68), address())
            mstore(add(ptr, 100), offs2)
            mstore(add(ptr, 132), 1)
            mstore(add(ptr, 164), caller())
            if iszero(call(gas(), address(), 0, ptr, 196, ptr, 0x0)) {
                // revert(0, 0)
                fail := 1
            }
        }
        console.log("fail", fail);
        if (!fail) console.log("--------------------------0");
    }

    fallback() external payable {
        bytes32 a_1;
        bytes32 a_2;
        bytes32 a_3;
        bytes32 a_4;
        bytes32 a_5;
        bytes32 a_6;
        bytes32 a_7;
        bytes32 a_8;
        console.log("----------test fallback");
        uint ptr;
        bytes calldata b;
        assembly {
            ptr := 100000000
            let cdlen := calldatasize()
            // Store at 0x40, to leave 0x00-0x3F for slot calculation below.
            calldatacopy(ptr, 0x00, cdlen)
            b.offset := 0
            b.length := cdlen
            a_1 := mload(add(ptr, 4))
            a_2 := mload(add(ptr, 36))
            a_3 := mload(add(ptr, 68))
            a_4 := mload(add(ptr, 100))
            a_5 := mload(add(ptr, 132))
            a_6 := mload(add(ptr, 164))
            a_7 := mload(add(ptr, 196))
            a_8 := mload(add(ptr, 228))
        }
        console.logBytes(b);
        console.log("calldata");
        console.logBytes32(a_1);
        console.logBytes32(a_2);
        console.logBytes32(a_3);
        console.logBytes32(a_4);
        console.logBytes32(a_5);
        console.logBytes32(a_6);
        console.logBytes32(a_7);
        console.logBytes32(a_8);
        // console.log("aasss over2");
        assembly {
            a_1 := mload(add(ptr, 260))
            a_2 := mload(add(ptr, 292))
            a_3 := mload(add(ptr, 324))
            a_4 := mload(add(ptr, 356))
            a_5 := mload(add(ptr, 388))
            a_6 := mload(add(ptr, 420))
            a_7 := mload(add(ptr, 452))
            a_8 := mload(add(ptr, 484))
            // a_8 := mload(add(ptr, 516))
        }
        console.logBytes32(a_1);
        console.logBytes32(a_2);
        console.logBytes32(a_3);
        console.logBytes32(a_4);
        console.logBytes32(a_5);
        console.logBytes32(a_6);
        console.logBytes32(a_7);
        console.logBytes32(a_8);
    }

    receive() external payable {}
}
