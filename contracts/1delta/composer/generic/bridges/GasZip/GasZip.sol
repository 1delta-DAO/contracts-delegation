// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BaseUtils} from "contracts/1delta/composer/generic/BaseUtils.sol";

contract GasZip is BaseUtils {
    /**
     * @notice Handles GasZip bridging (GasZip v1)
     * https://dev.gas.zip/gas/code-examples/evm-deposit/contract-forwarder
     *
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | gasZipRouter                 |
     * | 20     | 20             | receiver                     |
     * | 40     | 16             | amount                       |
     * | 56     | 32             | destinatinChainId            |
     */
    function _bridgeGasZip(uint256 currentOffset) internal returns (uint256) {
        assembly {
            function revertWith(code) {
                mstore(0, code)
                revert(0, 0x4)
            }

            let gasZipRouter := shr(96, calldataload(currentOffset))
            let receiver := shl(96, shr(96, calldataload(add(currentOffset, 20)))) // right padded zeros
            let amount := shr(128, calldataload(add(currentOffset, 40)))
            let destinatinChainId := calldataload(add(currentOffset, 56))
            currentOffset := add(currentOffset, 88)

            switch iszero(amount)
            case 1 {
                amount := selfbalance()
                switch iszero(amount)
                case 1 { revertWith(ZERO_BALANCE) }
            }

            switch eq(destinatinChainId, chainid())
            case 1 { revertWith(INVALID_DESTINATION) }
            switch or(receiver, 0)
            case 0 { revertWith(INVALID_RECEIVER) }

            let ptr := mload(0x40)
            // deposit(uint256 destinationChains, bytes32 to)
            mstore(ptr, 0xc9630cb000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), destinatinChainId)
            mstore(add(ptr, 0x24), receiver)

            if iszero(call(gas(), gasZipRouter, amount, ptr, 0x44, 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
        return currentOffset;
    }
}
