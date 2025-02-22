// SPDX-License-Identifier: BUSL-1.1

import {console} from "forge-std/console.sol";

pragma solidity 0.8.28;

contract FCaller {

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
