// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";

abstract contract DodoV2Quoter is Masks {
    /**
     * @notice Calculates amountOut for Dodo V2 pools
     * @dev Does not require overflow checks
     * @param sellAmount Input amount
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return newOffset Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 1              | sellQuote            |
     * | 21     | 2              | pId                  | pool index for flash validation
     * | 23     | 2              | clLength / pay flag  | <- 0: caller pays; 1: contract pays; greater: pre-funded
     * | 25     | clLength       | calldata             | calldata for flash loan
     */
    function _getDodoV2AmountOut(uint256 sellAmount, uint256 currentOffset) internal view returns (uint256 amountOut, uint256 newOffset) {
        address pair;
        uint256 sellQuote;
        uint256 clLength;
        assembly {
            let dodoData := calldataload(currentOffset)
            clLength := and(UINT16_MASK, shr(56, dodoData))
            sellQuote := and(UINT8_MASK, shr(88, dodoData))
            pair := shr(96, dodoData)
        }

        amountOut = _getDodoV2AmountOut(pair, sellQuote, sellAmount);
        assembly {
            switch lt(clLength, 3)
            case 1 { newOffset := add(25, currentOffset) }
            default { newOffset := add(add(25, currentOffset), clLength) }
        }
    }

    function _getDodoV2AmountOut(address pair, uint256 sellQuote, uint256 amountIn) private view returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            // get selector
            switch sellQuote
            case 0 {
                // querySellBase(address,uint256)
                mstore(ptr, 0x79a0487600000000000000000000000000000000000000000000000000000000)
            }
            default {
                // querySellQuote(address,uint256)
                mstore(ptr, 0x66410a2100000000000000000000000000000000000000000000000000000000)
            }
            mstore(add(ptr, 0x4), 0) // trader is zero
            mstore(add(ptr, 0x24), amountIn)
            // call pool
            if iszero(
                staticcall(
                    gas(),
                    pair,
                    ptr,
                    0x44, //
                    ptr,
                    0x20
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            amountOut := mload(ptr)
        }
    }
}
