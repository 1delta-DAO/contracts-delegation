// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {UniTypeSwapper} from "./UniType.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

/**
 * @title Uniswap V2 type swapper contract
 * @notice We do everything UniV2 here, incl Solidly, FoT, exactIn and -Out
 */
abstract contract SyncSwapper is UniTypeSwapper {
    /// @dev selector for swap(bytes,address,address,bytes)
    bytes32 internal constant SYNCSWAP_SELECTOR = 0x7132bb7f00000000000000000000000000000000000000000000000000000000;

    uint256 internal constant MAX_SINGLE_LENGTH_SYNCSWAP = 68;
    uint256 internal constant SKIP_LENGTH_SYNCSWAP = 46; // = 20+1+1+20+4

    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    address internal constant RITSU_STABLE_FACTORY = address(0);
    address internal constant RITSU_CLASSIC_FACTORY = address(0);

    constructor() {}

    /**
     * Executes an exact input swap internally across major UniV2 & Solidly style forks
     * Due to the nature of the V2 impleemntation, the callback is not triggered if no calldata is provided
     * As such, we never enter the callback implementation when using this function
     * @param amountIn sell amount
     * @param useFlashSwap if set to true, the amount in will not be transferred and a
     *                     payback is expected to be done in the callback
     * @return buyAmount output amount
     */
    function swapSyncExactInComplete(
        uint256 amountIn,
        uint256 amountOutMin,
        address payer,
        address receiver,
        bool useFlashSwap,
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := shr(96, calldataload(add(pathOffset, 22)))
            
            // get tokenIn
            let tokenIn := shr(96, calldataload(pathOffset))

            ////////////////////////////////////////////////////
            // Prepare the swap tx
            ////////////////////////////////////////////////////

            // selector for swap(...)
            mstore(ptr, SYNCSWAP_SELECTOR)
            mstore(add(ptr, 4), 0x80) // first param set offset
            mstore(add(ptr, 36), 0x0) // sender address

            ////////////////////////////////////////////////////
            // In case of a flash swap, we copy the calldata to
            // the execution parameters
            ////////////////////////////////////////////////////
            switch useFlashSwap
            case 1 {
                // store callback
                mstore(add(ptr, 68), address()) // callback receiver address
                mstore(add(ptr, 100), 0x100) // calldata offset
                mstore(add(ptr, 132), 0x60) // datalength
                mstore(add(ptr, 164), tokenIn) // tokenIn
                mstore(add(ptr, 196), receiver) // to
                mstore(add(ptr, 228), 0) // withdraw mode

                // we store the offset of the bytes calldata in the func call
                let calldataOffsetStart := add(ptr, 292)
                let _pathLength := pathLength
                calldatacopy(calldataOffsetStart, pathOffset, _pathLength)
                // store max amount
                mstore(add(calldataOffsetStart, _pathLength), shl(128, amountOutMin))
                // store amountIn
                mstore(add(calldataOffsetStart, add(_pathLength, 16)), shl(128, amountIn))
                _pathLength := add(_pathLength, 32)
                //store amountIn
                mstore(add(calldataOffsetStart, _pathLength), shl(96, payer))
                _pathLength := add(_pathLength, 20)

                // bytes length
                mstore(add(ptr, 260), _pathLength)
                if iszero(
                    call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        add(292, _pathLength), // input size = 164 (selector (4bytes) plus 5*32bytes)
                        ptr, // output
                        0x40 // output size = 0x40
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            ////////////////////////////////////////////////////
            // Otherwise, we have to assume that
            // the swap is prefunded, i.e. the input amount has
            // already been sent to the sync style pool
            ////////////////////////////////////////////////////
            default {
                ////////////////////////////////////////////////////
                // We store the bytes length to zero (no callback)
                // and directly trigger the swap
                ////////////////////////////////////////////////////
                mstore(add(ptr, 68), 0x0) // callback receiver address
                mstore(add(ptr, 100), 0x100) // calldata offset
                mstore(add(ptr, 132), 0x60) // datalength
                mstore(add(ptr, 164), tokenIn) // tokenIn
                mstore(add(ptr, 196), receiver) // to
                mstore(add(ptr, 228), 0) // withdraw mode
                mstore(add(ptr, 260), 0) // path length is zero

                if iszero(
                    call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        292, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        ptr, // output
                        0x40 // output size = 0x40
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
            buyAmount := mload(add(ptr, 0x20))
        }
    }
}
