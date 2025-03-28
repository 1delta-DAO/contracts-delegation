// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ERC20Transfers} from "./ERC20Transfers.sol";
import {AssetHandlingIds} from "../enums/ForwarderEnums.sol";

/**
 * @title Similar to composer transfers, except that we drop permit2
 */
contract AssetHandling is ERC20Transfers {
    function _transfers(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 transferOperation;
        assembly {
            let firstSlice := calldataload(currentOffset)
            transferOperation := shr(248, firstSlice)
            currentOffset := add(currentOffset, 1)
        }
        if (transferOperation == AssetHandlingIds.TRANSFER_FROM) {
            return _transferFrom(currentOffset, callerAddress);
        } else if (transferOperation == AssetHandlingIds.SWEEP) {
            return _sweep(currentOffset);
        } else if (transferOperation == AssetHandlingIds.WRAP_NATIVE) {
            return _wrap(currentOffset);
        } else if (transferOperation == AssetHandlingIds.UNWRAP_WNATIVE) {
            return _unwrap(currentOffset);
        } else if (transferOperation == AssetHandlingIds.APPROVE) {
            return _approve(currentOffset);
        }  else {
            _invalidOperation();
        }
    }

    /** These need to be overridden withc chain-specific data */

    function _wrap(uint256 currentOffset) internal virtual returns (uint256) {}

    function _unwrap(uint256 currentOffset) internal virtual returns (uint256) {}
}
