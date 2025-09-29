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
     * | 20     | 32             | receiver                     |
     * | 52     | 16             | amount                       |
     * | 68     | 32             | destinatinChainId            |
     */
    function _bridgeGasZip(uint256 currentOffset) internal returns (uint256) {
        assembly {
            function revertWith(code) {
                mstore(0, code)
                revert(0, 0x4)
            }

            let gasZipRouter := shr(96, calldataload(currentOffset))
            let receiver := calldataload(add(currentOffset, 20))
            let amount := shr(128, calldataload(add(currentOffset, 52)))
            let destinatinChainId := calldataload(add(currentOffset, 68))
            currentOffset := add(currentOffset, 100)

            // amount zero means sefbalance
            switch iszero(amount)
            case 1 {
                amount := selfbalance()
                // revert if no balance to send
                if iszero(amount) { revertWith(ZERO_BALANCE) }
            }

            // prevent same-chain
            if eq(destinatinChainId, chainid()) { revertWith(INVALID_DESTINATION) }

            // check that receiver is nonzero
            if eq(receiver, 0) { revertWith(INVALID_RECEIVER) }

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
