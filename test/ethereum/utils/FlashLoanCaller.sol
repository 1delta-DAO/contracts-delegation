// SPDX-License-Identifier: BUSL-1.1

import {console} from "forge-std/console.sol";

pragma solidity 0.8.28;

interface IAllFlashLoans {
    function flashLoan(address recipient, address[] memory tokens, uint256[] memory amounts, bytes memory userData) external;

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params, //
        uint16 referralCode
    ) external;
}

contract FCaller {
    function callFlash(
        address target,
        address receiver,
        address asset,
        uint112 amount,
        bytes calldata data //
    ) external {
        assembly {
            let ptr := mload(0x40)
            // flashLoan(...)
            mstore(ptr, 0x5c38449e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), receiver)
            mstore(add(ptr, 36), 0x80) // offset assets
            mstore(add(ptr, 68), 0xc0) // offset amounts
            mstore(add(ptr, 100), 0x100) // offset modes
            mstore(add(ptr, 132), 1) // onBefhalfOf
            mstore(add(ptr, 164), asset) // offset calldata
            mstore(add(ptr, 196), 1) // referral code
            mstore(add(ptr, 228), amount) // length assets
            mstore(add(ptr, 260), data.length) // length calldata
            calldatacopy(add(ptr, 292), data.offset, data.length) // calldata
            if iszero(
                call(
                    gas(),
                    target,
                    0x0,
                    ptr,
                    add(data.length, 324), // = 10 * 32 + 4
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

    function callFlashAave(
        address target,
        address receiver,
        address asset,
        uint112 amount,
        uint16 ref,
        bytes calldata data //
    ) external {
        assembly {
            let ptr := mload(0x40)
            // flashLoanSimple(...)
            mstore(ptr, 0x42b0b77c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), receiver)
            mstore(add(ptr, 36), asset) // offset assets
            mstore(add(ptr, 68), amount) // offset amounts
            mstore(add(ptr, 100), 0xa0) // offset modes
            mstore(add(ptr, 132), ref) // onBefhalfOf
            mstore(add(ptr, 164), data.length) // length calldata
            calldatacopy(add(ptr, 196), data.offset, data.length) // calldata
            if iszero(
                call(
                    gas(),
                    target,
                    0x0,
                    ptr,
                    add(data.length, 228), // = 10 * 32 + 4
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
        address recipient,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata userData //
    ) external {
        console.log("enter flash loan");
        uint offs;
        assembly {
            offs := userData.offset
        }
        console.log("test", offs);
        console.logBytes(userData);
    }

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params, //
        uint16 referralCode
    ) external {
        console.log("enter flash loan-----aave");
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
