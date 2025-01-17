// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title DodoV2 swapper contract
 */
abstract contract DodoV2Swapper {
    /**
     * Executes a swap on DODO V2 exact in
     * The pair address is fetched from the factory
     * @param sellQuote if 0, the selector is `sellBase`, otherwise use sellBase
     * @param pair pair address
     * @param receiver receiver address
     * @return amountOut buy amount
     */
    function swapDodoV2ExactIn(uint8 sellQuote, address pair, address receiver) internal returns (uint256 amountOut) {
        assembly {
            // determine selector
            switch sellQuote
            case 0 {
                // sellBase
                mstore(0x0, 0xbd6015b400000000000000000000000000000000000000000000000000000000)
            }
            default {
                // sellQuote
                mstore(0x0, 0xdd93f59a00000000000000000000000000000000000000000000000000000000)
            }
            mstore(0x4, receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns the output amount directly
            amountOut := mload(0x0)
        }
    }
}
