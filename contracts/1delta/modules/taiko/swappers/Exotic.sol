// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {SyncSwapper} from "./SyncType.sol";

// solhint-disable max-line-length

/**
 * @title Exotic swapper contract
 * @notice Typically includes DEXs that do not fall into a broader category
 */
abstract contract ExoticSwapper is SyncSwapper {
    /// @dev Maximum high path length of a dex that only has a pool address reference
    uint256 internal constant RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS = 64;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS = 65;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_HIGH = 66;
    
    /// @dev Length of a swap that only has a pool address reference
    uint256 internal constant SKIP_LENGTH_ADDRESS = 42; // = 20+1+1+20

    /// @dev Maximum high path length for pool address and param (u8)
    uint256 internal constant RECEIVER_OFFSET_SINGLE_LENGTH_ADDRESS_AND_PARAM = 65;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_AND_PARAM = 66;
    uint256 internal constant MAX_SINGLE_LENGTH_ADDRESS_AND_PARAM_HIGH = 67;
    
    /// @dev Length of a swap that only has a pool address an param (u8)
    uint256 internal constant SKIP_LENGTH_ADDRESS_AND_PARAM = 43; // = 20+1+1+20

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
