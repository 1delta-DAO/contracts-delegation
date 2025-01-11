// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract DodoV2Quoter {
    function getDodoV2AmountOut(address pair, uint256 sellQuote, uint256 amountIn) internal view returns (uint256 amountOut) {
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
