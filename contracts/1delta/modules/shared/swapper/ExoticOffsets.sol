// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

/**
 * @title Offsets for exotic swaps
 */
abstract contract ExoticOffsets {
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

}
