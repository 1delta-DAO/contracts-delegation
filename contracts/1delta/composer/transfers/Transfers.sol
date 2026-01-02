// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {AssetTransfers} from "./AssetTransfers.sol";
import {TransferIds} from "../enums/DeltaEnums.sol";

/**
 * @title Token transfer contract
 * @notice Should work across all EVMs - uses Uniswap style Permit2
 */
contract Transfers is AssetTransfers {
    /**
     * @notice Routes to appropriate transfer operation based on operation ID
     * @dev Supports transferFrom, sweep, unwrap, permit2TransferFrom, and approve operations
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description     |
     * |--------|----------------|-----------------|
     * | 0      | 1              | transferOperation|
     */
    function _transfers(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 transferOperation;
        assembly {
            let firstSlice := calldataload(currentOffset)
            transferOperation := shr(248, firstSlice)
            currentOffset := add(currentOffset, 1)
        }
        if (transferOperation == TransferIds.TRANSFER_FROM) {
            return _transferFrom(currentOffset, callerAddress);
        } else if (transferOperation == TransferIds.SWEEP) {
            return _sweep(currentOffset);
        } else if (transferOperation == TransferIds.UNWRAP_WNATIVE) {
            return _unwrap(currentOffset);
        } else if (transferOperation == TransferIds.PERMIT2_TRANSFER_FROM) {
            return _permit2TransferFrom(currentOffset, callerAddress);
        } else if (transferOperation == TransferIds.APPROVE) {
            return _approve(currentOffset);
        } else {
            _invalidOperation();
        }
    }
}
