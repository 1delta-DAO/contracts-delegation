// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Masks} from "../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../swappers/dex/DexTypeMappings.sol";
import {V3TypeQuoter} from "./dex/V3TypeQuoter.sol";
import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";

contract QuoterLight is Masks, V3TypeQuoter, ERC20Selectors {
    error InvalidDexId();
    error InvalidSplitFormat();

    function quote(bytes calldata data) external view returns (uint256 amountOut) {
        return quoteExactInput();
    }
    //////////////////

    function quoteExactInput() internal view returns (uint256) {
        uint256 amountIn;
        uint256 minimumAmountReceived;
        address tokenIn;
        uint256 currentOffset = 0;
        /*
         * Store the data for the callback as follows
         * | Offset | Length (bytes) | Description          |
         * |--------|----------------|----------------------|
         * | 0      | 16             | amount               | <-- input amount
         * | 16     | 16             | amountMax            | <-- slippage check
         * | 32     | 20             | tokenIn              |
         * | 52     | any            | data                 |
         *
         * `data` is a path matrix definition (see BaseSwapepr)
         */
        assembly {
            minimumAmountReceived := calldataload(0x4)
            amountIn := shr(128, minimumAmountReceived)
            minimumAmountReceived := and(UINT128_MASK, minimumAmountReceived)
            currentOffset := add(currentOffset, 32)
            let dataStart := calldataload(currentOffset)
            tokenIn := shr(96, dataStart)
            currentOffset := add(20, currentOffset)

            /**
             * if the amount is zero, we assume that the contract balance is swapped
             */
            if iszero(amountIn) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, address())
                // call to token
                pop(
                    staticcall(
                        gas(),
                        tokenIn, // collateral token
                        0x0,
                        0x24,
                        0x0,
                        0x20
                    )
                )
                // load the retrieved balance
                amountIn := mload(0x0)
            }
        }
        return _quoteSwapSplitOrRoute(amountIn, tokenIn, currentOffset);
    }

    function _quoteSwapSplitOrRoute(uint256 amountIn, address tokenIn, uint256 currentOffset)
        internal
        view
        returns (uint256 amountOut)
    {
        uint256 swapMaxIndex;
        uint256 splitsMaxIndex;
        assembly {
            let datas := calldataload(currentOffset)
            swapMaxIndex := shr(248, datas)
            splitsMaxIndex := and(UINT8_MASK, shr(240, datas))
            currentOffset := add(currentOffset, 2)
        }

        address nextToken;
        uint256 received;
        if (swapMaxIndex == 0) {
            // Single swap or split swap
            if (splitsMaxIndex == 0) {
                assembly {
                    nextToken := shr(96, calldataload(currentOffset))
                    currentOffset := add(currentOffset, 40) // skip the receiver: 20 + 20
                }

                (amountOut, currentOffset) = _quoteSingleSwap(amountIn, tokenIn, nextToken, currentOffset);
            }
        }
        // else {
        //     // Split swap
        // }
        // else {
        //     // Multi-hop swap
        // }
    }

    function _quoteSingleSwap(uint256 amountIn, address tokenIn, address tokenOut, uint256 currentOffset)
        internal
        view
        returns (uint256 amountOut, uint256)
    {
        uint256 dexTypeId;
        assembly {
            dexTypeId := shr(248, calldataload(currentOffset))
            currentOffset := add(currentOffset, 1)
        }
        if (dexTypeId == DexTypeMappings.UNISWAP_V3_ID) {
            return getV3TypeAmountOut(amountIn, tokenIn, tokenOut, currentOffset);
        } else {
            revert InvalidDexId();
        }
    }
}
