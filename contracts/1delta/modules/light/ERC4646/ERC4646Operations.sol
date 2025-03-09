// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {Slots} from "../../shared/storage/Slots.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {ERC4646Transfers} from "./ERC4646Transfers.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * ERC4646 classifier enums
 */
library ERC4646Ids {
    uint256 internal constant DEPOSIT = 0;
    uint256 internal constant WITHDRAW = 1;
}

/**
 * @notice ERC4646 deposit and withdraw actions
 */
abstract contract ERC4646Operations is ERC4646Transfers {
    /// @notice withdraw from (e.g. morpho) vault
    function _ERC4646Operations(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 erc4646Operation;
        assembly {
            erc4646Operation := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }
        /** ERC6464 deposit */
        if (erc4646Operation == ERC4646Ids.DEPOSIT) {
            currentOffset = _erc4646Deposit(currentOffset);
        }
        /** ERC6464 withdraw */
        else if (erc4646Operation == ERC4646Ids.WITHDRAW) {
            currentOffset = _erc4646Withdraw(currentOffset, callerAddress);
        } else {
            _invalidOperation();
        }
        return currentOffset;
    }
}
