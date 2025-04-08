// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ERC20Transfers} from "./ERC20Transfers.sol";
import {TransferIds} from "../enums/DeltaEnums.sol";

/**
 * @title Token transfer contract - should work across all EVMs - user Uniswap style Permit2
 */
contract Transfers is ERC20Transfers {
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
        } else if (transferOperation == TransferIds.WRAP_NATIVE) {
            return _wrap(currentOffset);
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

    /** These need to be overridden withc chain-specific data */

    function _wrap(uint256 currentOffset) internal virtual returns (uint256) {}

    function _unwrap(uint256 currentOffset) internal virtual returns (uint256) {}
}
