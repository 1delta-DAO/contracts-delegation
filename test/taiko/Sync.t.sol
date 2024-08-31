// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";


// solhint-disable max-line-length

interface ISyncSwap {
    function swap(bytes calldata _data, address _sender, address _callback, bytes calldata _callbackData) external;

    function master() external view returns (address);
}

interface ISyncTest {
    function swap(
        bytes calldata _data,
        address _sender,
        address _callback,
        bytes calldata _callbackData //
    ) external;
}

contract SyncTest {
    receive() external payable {}

    fallback() external payable {
        bytes calldata b;
        assembly {
            let ptr := 100000000
            let cdlen := calldatasize()
            // Store at 0x40, to leave 0x00-0x3F for slot calculation below.
            calldatacopy(ptr, 0x00, cdlen)
            b.offset := 0
            b.length := cdlen
        }
        console.logBytes(b);
    }
}

contract ComposerTestTaiko is DeltaSetup {
    function test_taiko_sync() external {
        SyncTest st = new SyncTest();
                address tokenIn = address(1);
        address to = address(2);
        bytes memory _data = abi.encode(tokenIn, to, uint8(99));

          bytes32 data32 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;
        bytes memory _data2 = abi.encode(data32,data32);
              address sender = address(11);
        address callback = address(12);
        ISyncTest(address(st)).swap(_data, sender, callback, _data2);

        console.log("test---");
        extCall(address(st));
    }

    bytes32 internal constant SYNCSWAP_SELECTOR = 0x7132bb7f00000000000000000000000000000000000000000000000000000000;

    function extCall(address t) internal {
        address tokenIn = address(1);
        address to = address(2);
        uint8 wm = 99;
        uint len = 64;
        bytes32 data = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;
        address sender = address(11);
        address callback = address(12);
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, SYNCSWAP_SELECTOR)
            mstore(add(ptr, 4), 0x80)
            mstore(add(ptr, 36), sender)
            mstore(add(ptr, 68), callback)
            mstore(add(ptr, 100), 0x100)
            mstore(add(ptr, 132), 0x60) // datalength
            mstore(add(ptr, 164), tokenIn)
            mstore(add(ptr, 196), to)
            mstore(add(ptr, 228), wm)
            mstore(add(ptr, 260), len)
            mstore(add(ptr, 292), data)
            mstore(add(ptr, 324), data)
            pop(call(gas(), t, 0, ptr, 356, 0x0, 0x0))
        }
    }
}
// 0x7132bb7f00000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000080
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x0000000000000000000000000000000000000000000000000000000000000002
// 0x0000000000000000000000000000000000000000000000000000000000000100
// 0x0000000000000000000000000000000000000000000000000000000000000060
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000000000000000000000000000000000000000000063
// 0x0000000000000000000000000000000000000000000000000000000000000060
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000000000000000000000000000000000000000000063

// 0x7132bb7f00000000000000000000000000000000000000000000000000000000
// 0x0000000000000000000000000000000000000000000000000000000000000080
// 0x0000000000000000000000000000000000000000000000000000000000000001
// 0x0000000000000000000000000000000000000000000000000000000000000002
// 0x0000000000000000000000000000000000000000000000000000000000000100
// 0x0000000000000000000000000000000000000000000000000000000000000060
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000000000000000000000000000000000000000000063
// 0x0000000000000000000000000000000000000000000000000000000000000080
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496
// 0x0000000000000000000000000000000000000000000000000000000000000063
