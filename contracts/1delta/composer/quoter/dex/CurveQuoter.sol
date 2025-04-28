// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";

abstract contract CurveQuoter is Masks {
    bytes32 internal constant CURVE_FORK_CALCULATE_SWAP = 0xa95b089f00000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant CURVE_GET_DY = 0x556d6e9f00000000000000000000000000000000000000000000000000000000;

    bytes32 internal constant CURVE_GET_DY_128 = 0x5e0d443f00000000000000000000000000000000000000000000000000000000;

    function _getCurveAmountOut(uint256 amountIn, uint256 currentOffset) internal view returns (uint256 amountOut, uint256) {
        address pool;
        uint256 indexIn;
        uint256 indexOut;
        uint256 selectorId;
        assembly {
            let curveData := calldataload(currentOffset)
            pool := shr(96, curveData)
            indexIn := and(shr(88, curveData), UINT8_MASK)
            indexOut := and(shr(80, curveData), UINT8_MASK)
            selectorId := and(shr(72, curveData), UINT8_MASK)
        }

        amountOut = _getCurveAmountOutPrivate(indexIn, indexOut, selectorId, pool, amountIn);

        assembly {
            currentOffset := add(currentOffset, 25)
        }

        return (amountOut, currentOffset);
    }

    function _getCurveAmountOutPrivate(
        uint256 indexIn,
        uint256 indexOut,
        uint256 selectorId,
        address pool,
        uint256 amountIn
    )
        private
        view
        returns (uint256 amountOut)
    {
        assembly {
            let ptr := mload(0x40)

            switch selectorId
            case 0 {
                // selector for exchange(int128,int128,uint256,uint256,address)
                mstore(ptr, CURVE_GET_DY_128)
            }
            case 1 {
                // selector for exchange(int128,int128,uint256,uint256)
                mstore(ptr, CURVE_GET_DY_128)
            }
            case 2 {
                // selector for exchange(uint256,uint256,uint256,uint256,address)
                mstore(ptr, CURVE_GET_DY)
            }
            case 3 {
                // selector for exchange(uint256,uint256,uint256,uint256)
                mstore(ptr, CURVE_GET_DY)
            }
            case 4 {
                // selector exchange_underlying(int128,int128,uint256,uint256,address)
                mstore(ptr, CURVE_GET_DY_128)
            }
            case 5 {
                // selector for exchange_underlying(int128,int128,uint256,uint256)
                mstore(ptr, CURVE_GET_DY_128)
            }
            case 6 {
                // exchange_underlying(uint256,uint256,uint256,uint256,address)
                mstore(ptr, CURVE_GET_DY)
            }
            case 7 {
                // selector for exchange_underlying(uint256,uint256,uint256,uint256)
                mstore(ptr, CURVE_GET_DY)
            }
            case 200 {
                // selector for swap(uint8,uint8,uint256,uint256,uint256)
                mstore(ptr, CURVE_FORK_CALCULATE_SWAP)
            }
            default { revert(0, 0) }
            mstore(add(ptr, 0x04), indexIn)
            mstore(add(ptr, 0x24), indexOut)
            mstore(add(ptr, 0x44), amountIn)
            if iszero(staticcall(gas(), pool, ptr, 0x64, 0x0, 0x20)) { revert(0, 0) }
            amountOut := mload(0x0)
        }
    }

    function getCurveAmountIn(address pool, uint256 indexIn, uint256 indexOut, uint256 amountOut) internal view returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)

            // selector for get_dx(int128,int128,uint256)
            mstore(ptr, 0x67df02ca00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), indexIn)
            mstore(add(ptr, 0x24), indexOut)
            mstore(
                add(ptr, 0x44),
                div(
                    // we upscale to avoid insufficient amount received
                    // tah is, becaus the feature is not accurate
                    mul(
                        10000050, // 0.05bp = 10_000_0_50
                        amountOut
                    ),
                    10000000
                )
            )
            // ignore whether it succeeds as we expect the swap to fail in that case
            pop(staticcall(gas(), pool, ptr, 0x64, 0x0, 0x20))

            amountIn := mload(0x0)
        }
    }
}
