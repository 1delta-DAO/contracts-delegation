// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {FlashLoanCallbacks} from "./FlashLoanCallbacks.sol";

/**
 * @title Flash loan aggregator
 * @author 1delta Labs AG
 */
contract UniversalFlashLoan is FlashLoanCallbacks {
    /**
     * Empty flash loaner
     */
    function _universalFlashLoan(uint256, address) internal virtual returns (uint256) {
        assembly {
            revert(0, 0)
        }
    }
}

