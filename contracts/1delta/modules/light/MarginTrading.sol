// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {BaseLending} from "./BaseLending.sol";
import {BaseSwapper} from "./BaseSwapper.sol";
import {V2ReferencesBase} from "./swappers/V2References.sol";
import {V3ReferencesBase} from "./swappers/V3References.sol";
import {PreFunder} from "../shared/funder/PreFunder.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract MarginTrading is BaseLending, BaseSwapper, V2ReferencesBase, V3ReferencesBase, PreFunder {
    // errors
    error NoBalance();

    uint256 internal constant PATH_OFFSET_CALLBACK_V2 = 164;
    uint256 internal constant PATH_OFFSET_CALLBACK_V3 = 132;
    uint256 internal constant NEXT_SWAP_V3_OFFSET = 176; //PATH_OFFSET_CALLBACK_V3 + SKIP_LENGTH_UNOSWAP;
    uint256 internal constant NEXT_SWAP_V2_OFFSET = 208; //PATH_OFFSET_CALLBACK_V2 + SKIP_LENGTH_UNOSWAP;

    constructor() BaseSwapper() {}

    // uniswap v3
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 pathLength;
        assembly {
            pathLength := path.length
            let firstWord := calldataload(PATH_OFFSET_CALLBACK_V3)
            let dexId := and(UINT8_MASK, shr(80, firstWord))
            tokenIn := shr(96, firstWord)
            // second word
            firstWord := calldataload(164) // PATH_OFFSET_CALLBACK_V3 + 32
            tokenOut := and(ADDRESS_MASK, firstWord)

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            switch dexId
            case 0 {
                mstore(s, UNI_V3_FF_FACTORY)
                let p := add(s, 21)
                // Compute the inner hash in-place
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(p, tokenOut)
                    mstore(add(p, 32), tokenIn)
                }
                default {
                    mstore(p, tokenIn)
                    mstore(add(p, 32), tokenOut)
                }
                mstore(add(p, 64), and(UINT16_MASK, shr(160, firstWord)))
                mstore(p, keccak256(p, 96))
                p := add(p, 32)
                mstore(p, UNI_POOL_INIT_CODE_HASH)
            }
            default {
                revert(0, 0)
            }
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, pathLength);
    }

    function clSwapCallback(int256 amount0Delta, int256 amount1Delta, address tokenIn, address tokenOut, uint256 pathLength) private {
        uint256 tradeId;
        address payer;
        bool isExactIn;
        bool multihop;
        uint256 maximumAmount;
        uint256 amountReceived;
        uint256 amountToPay;
        assembly {
            switch sgt(amount0Delta, 0)
            case 1 {
                isExactIn := lt(tokenIn, tokenOut)
                amountReceived := sub(0, amount1Delta)
                amountToPay := amount0Delta
            }
            default {
                isExactIn := lt(tokenOut, tokenIn)
                amountReceived := sub(0, amount0Delta)
                amountToPay := amount1Delta
            }
            ////////////////////////////////////////////////////
            // We fetch the original initiator of the swap function
            // It is represented by the last 20 bytes of the path
            ////////////////////////////////////////////////////
            payer := and(
                ADDRESS_MASK,
                calldataload(
                    add(
                        100, // PATH_OFFSET_CALLBACK_V3 - 32
                        pathLength
                    ) // last 32 bytes
                )
            )
            ////////////////////////////////////////////////////
            // The maximum amount starts at the 52nd byte from
            // the right
            ////////////////////////////////////////////////////
            maximumAmount := and(
                UINT128_MASK,
                calldataload(
                    add(
                        80, // PATH_OFFSET_CALLBACK_V3 - 52
                        pathLength
                    ) // last 52 bytes
                )
            )
            // skim address from calldata
            pathLength := sub(pathLength, 36)
            // assume a multihop if the calldata is longer than 67
            multihop := gt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP)
            // use tradeId as tradetype
            tradeId := and(
                calldataload(121), // PATH_OFFSET_CALLBACK_V3 - 11
                UINT8_MASK
            )
        }
        _deltaComposeInternal(payer, amountReceived, amountToPay, 0, pathLength);
    }

    // The uniswapV2 style callback for exact forks
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 pathLength;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            pathLength := path.length
            // revert if sender param is not this address
            if xor(sender, address()) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // fetch tokens
            let firstWord := calldataload(PATH_OFFSET_CALLBACK_V2)
            let pId := and(UINT8_MASK, shr(80, firstWord))
            tokenIn := shr(96, firstWord)
            tokenOut := and(ADDRESS_MASK, calldataload(196)) // PATH_OFFSET_CALLBACK_V2 + 32
            let ptr := mload(0x40)
            switch lt(tokenIn, tokenOut)
            case 0 {
                mstore(add(ptr, 0x14), tokenIn)
                mstore(ptr, tokenOut)
            }
            default {
                mstore(add(ptr, 0x14), tokenOut)
                mstore(ptr, tokenIn)
            }
            let salt := keccak256(add(ptr, 0x0C), 0x28)
            // validate callback
            switch pId
            case 100 {
                mstore(ptr, UNI_V2_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_UNI_V2)
            }
            default {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // verify that the caller is a v2 type pool
            if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            // this occurs if someone sends valid
            // calldata with this contract as recipient
            if xor(sender, address()) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, pathLength);
    }

    /**
     * Flash swap callback for all UniV2 and Solidly type DEXs
     * @param amount0 amount of token0 received
     * @param amount1 amount of token1 received
     */
    function _v2StyleCallback(uint256 amount0, uint256 amount1, uint256 pathLength) private {
        uint256 tradeId;
        uint256 maxAmount;
        uint256 amountReceived;
        address payer;
        bool multihop;
        uint256 amountToPay;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            tradeId := and(calldataload(153), UINT8_MASK) // interaction identifier at PATH_OFFSET_CALLBACK_V2 - 11
            ////////////////////////////////////////////////////
            // We fetch the original initiator of the swap function
            // It is represented by the last 20 bytes of the path
            ////////////////////////////////////////////////////
            payer := and(
                ADDRESS_MASK,
                calldataload(
                    add(
                        132, // PATH_OFFSET_CALLBACK_V2 - 32
                        pathLength
                    ) // last 32 bytes
                )
            )
            ////////////////////////////////////////////////////
            // amount [128|128] starting at the 52th byte
            // from the right as [maximum|amountToPay]
            // here we fetch the entire amount and decompose it
            ////////////////////////////////////////////////////
            maxAmount := calldataload(
                add(
                    112, // PATH_OFFSET_CALLBACK_V2 - 52
                    pathLength
                ) // last 52 bytes
            )
            ////////////////////////////////////////////////////
            // pay amount provided in lower 16 bytes
            // we assume that this value is zero for
            // exactOut swaps as we calculate the amount in this
            // case
            ////////////////////////////////////////////////////
            amountToPay := and(UINT128_MASK, maxAmount)
            // max as upper bytes
            maxAmount := shr(128, maxAmount)
            // skim address from calldatas
            pathLength := sub(pathLength, 52)
            // assume a multihop if the calldata is longer than 64
            multihop := gt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP)
            // assign amount received
            switch iszero(amount0)
            case 0 {
                amountReceived := amount0
            }
            default {
                amountReceived := amount1
            }
        }
        _deltaComposeInternal(payer, amountReceived, amountToPay, 0, pathLength);
    }

    /**
     * Swaps exact output while avoiding flash swaps whenever possible
     * Funds are sent to receiver address
     * Path is assumed to start from output token
     * The input amount is cached and not directly returned by this function
     * @param amountOut buy amount
     * @param receiver address
     */
    function swapExactOutInternal(
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        address receiver,
        uint256 pathOffset,
        uint256 pathLength
    ) internal {
        // fetch the pool identifier from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (poolId < UNISWAP_V3_MAX_ID) {
            _swapUniswapV3PoolExactOut(amountOut, maxIn, payer, receiver, pathOffset, pathLength);
        }
        // iZi
        else if (poolId == IZI_ID) {
            _swapIZIPoolExactOut(amountOut, maxIn, payer, receiver, pathOffset, pathLength);
        }
        // Balancer V2
        else if (poolId == BALANCER_V2_ID) {
            address tokenIn;
            uint256 amountIn;
            bytes32 balancerPoolId;
            address tokenOut;
            assembly {
                tokenOut := shr(96, calldataload(pathOffset))
                tokenIn := shr(96, calldataload(add(pathOffset, SKIP_LENGTH_BALANCER_V2)))
                balancerPoolId := calldataload(add(pathOffset, 22))
            }
            ////////////////////////////////////////////////////
            // We calculate the required amount for the next swap
            ////////////////////////////////////////////////////
            amountIn = _getBalancerAmountIn(balancerPoolId, tokenIn, tokenOut, amountOut);

            if (pathLength > MAX_SINGLE_LENGTH_BALANCER_V2) {
                // remove the last token from the path
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_BALANCER_V2)
                    pathLength := sub(pathLength, SKIP_LENGTH_BALANCER_V2)
                }
                swapExactOutInternal(
                    amountIn,
                    maxIn,
                    payer,
                    address(this), // balancer pulls from this address
                    pathOffset,
                    pathLength
                );
            }
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                // if(maxIn < amountIn) revert Slippage();
                assembly {
                    if lt(maxIn, amountIn) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                _deltaComposeInternal(payer, 0, amountIn, 0, pathLength);
            }
            _swapBalancerExactOut(balancerPoolId, tokenIn, tokenOut, receiver, amountOut);
        }
        // Curve NG
        else if (poolId == CURVE_RECEIVED_ID) {
            address tokenIn;
            uint256 amountIn;
            uint256 indexIn;
            uint256 indexOut;
            address pool;
            assembly {
                tokenIn := shr(96, calldataload(add(pathOffset, 45)))
                let indexesAndPool := calldataload(add(pathOffset, 22))
                pool := shr(96, indexesAndPool)
                indexIn := and(shr(88, indexesAndPool), 0xff)
                indexOut := and(shr(80, indexesAndPool), 0xff)
            }
            ////////////////////////////////////////////////////
            // We calculate the required amount for the next swap
            ////////////////////////////////////////////////////
            amountIn = _getNGAmountIn(pool, indexIn, indexOut, amountOut);
            if (pathLength > MAX_SINGLE_LENGTH_CURVE) {
                // remove the last token from the path
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_CURVE)
                    pathLength := sub(pathLength, SKIP_LENGTH_CURVE)
                }
                swapExactOutInternal(
                    amountIn,
                    maxIn,
                    payer,
                    pool, // ng is pre-funded
                    pathOffset,
                    pathLength
                );
            }
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                // if(maxIn < amountIn) revert Slippage();
                assembly {
                    if lt(maxIn, amountIn) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                _deltaComposeInternal(payer, 0, amountIn, 0, pathLength);
            }

            _swapCurveReceivedExactOut(pool, pathOffset, indexIn, indexOut, amountIn, receiver);
        }
        // uniswapV2 style
        else if (poolId < UNISWAP_V2_MAX_ID) {
            address tokenIn;
            uint256 amountIn;
            address pair;
            address tokenOut;
            // this will stack too deep
            {
                uint256 feeDenom;
                assembly {
                    tokenOut := shr(96, calldataload(pathOffset))
                    tokenIn := shr(96, calldataload(add(pathOffset, SKIP_LENGTH_UNOSWAP)))
                    pair := shr(96, calldataload(add(pathOffset, 22)))
                    feeDenom := and(UINT16_MASK, calldataload(add(pathOffset, 12)))
                }
                ////////////////////////////////////////////////////
                // We calculate the required amount for the next swap
                ////////////////////////////////////////////////////
                amountIn = getV2AmountInDirect(pair, tokenIn, tokenOut, amountOut, feeDenom, poolId);
            }
            ////////////////////////////////////////////////////
            // If the path includes more pairs, we nest another exact out swap
            // The funds of this exact out swap are sent to the pair
            // This is done by re-calling this same function after skimming the
            // data parameter by the leading token config
            ////////////////////////////////////////////////////
            if (pathLength > MAX_SINGLE_LENGTH_UNOSWAP) {
                // remove the last token from the path
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                }
                swapExactOutInternal(amountIn, maxIn, payer, pair, pathOffset, pathLength);
            }
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                // if(maxIn < amountIn) revert Slippage();
                assembly {
                    if lt(maxIn, amountIn) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                // amountIn has to be paid, push that one
                _deltaComposeInternal(payer, 0, amountIn, 0, 0);
            }
            _swapV2StyleExactOut(
                tokenIn,
                tokenOut,
                pair,
                amountOut,
                0, // no slippage check
                address(0), // no payer
                receiver,
                false, // no flash swap
                pathOffset,
                pathLength
            );
            // special case: Moe LB, no flash swaps, recursive nesting is applied
        } else if (poolId == LB_ID) {
            address tokenIn;
            uint256 amountIn;
            bool swapForY;
            address pair;
            {
                address tokenOut;
                assembly {
                    tokenOut := shr(96, calldataload(pathOffset))
                    tokenIn := shr(96, calldataload(add(pathOffset, 42)))
                    pair := shr(96, calldataload(add(pathOffset, 22)))
                }
                ////////////////////////////////////////////////////
                // We calculate the required amount for the next swap
                ////////////////////////////////////////////////////
                (amountIn, swapForY) = getLBAmountIn(tokenOut, pair, amountOut);
            }
            ////////////////////////////////////////////////////
            // If the path includes more pairs, we nest another exact out swap
            // The funds of this exact out swap are sent to the LB pair
            // This is done by re-calling this same function after skimming the
            // data parameter by the leading token config
            ////////////////////////////////////////////////////
            if (pathLength > MAX_SINGLE_LENGTH_ADDRESS) {
                // limit is 20+1+1+20+20+2+1
                // remove the last token from the path
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_ADDRESS)
                    pathLength := sub(pathLength, SKIP_LENGTH_ADDRESS)
                }
                swapExactOutInternal(amountIn, maxIn, payer, pair, pathOffset, pathLength);
            }
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                // if(maxIn < amountIn) revert Slippage();
                assembly {
                    if lt(maxIn, amountIn) {
                        mstore(0, SLIPPAGE)
                        revert(0, 0x4)
                    }
                }
                _deltaComposeInternal(payer, 0, amountIn, 0, 0);
            }
            ////////////////////////////////////////////////////
            // The swap is executed at the end and sends
            // the funds to the receiver addresss
            ////////////////////////////////////////////////////
            swapLBexactOut(pair, swapForY, amountOut, receiver);
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
    }

    /**
     * Flash-swaps exact output
     * Funds are sent to receiver address
     * Path is assumed to start from output token
     * The input amount is cached and not directly returned by this function
     * @param amountOut buy amount
     * @param payer payer address (MUST be this contract or caller)
     */
    function flashSwapExactOutInternal(uint256 amountOut, uint256 maxIn, address payer, uint256 pathOffset, uint256 pathLength) internal {
        // fetch the pool identifier from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (poolId < UNISWAP_V3_MAX_ID) {
            _swapUniswapV3PoolExactOut(amountOut, maxIn, payer, address(this), pathOffset, pathLength);
        }
        // iZi
        else if (poolId == IZI_ID) {
            _swapIZIPoolExactOut(amountOut, maxIn, payer, address(this), pathOffset, pathLength);
            // uniswapV2 style
        } else if (poolId < UNISWAP_V2_MAX_ID) {
            address tokenOut;
            address tokenIn;
            address pair;
            assembly {
                tokenOut := shr(96, calldataload(pathOffset))
                tokenIn := shr(96, calldataload(add(pathOffset, SKIP_LENGTH_UNOSWAP)))
                pair := shr(96, calldataload(add(pathOffset, 22)))
            }
            _swapV2StyleExactOut(tokenIn, tokenOut, pair, amountOut, maxIn, payer, address(this), true, pathOffset, pathLength);
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
    }

    // Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactInInternal(uint256 amountIn, uint256 amountOutMinimum, address payer, uint256 pathOffset, uint256 pathLength) internal {
        // fetch the pool poolId from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
        }
        // uniswapV3 types
        if (poolId < UNISWAP_V3_MAX_ID) {
            address receiver;
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH) // see swapExactIn
                case 1 {
                    receiver := address()
                }
                default {
                    let nextId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNISWAP - 10
                    switch gt(nextId, 99)
                    case 1 {
                        receiver := shr(
                            96,
                            calldataload(
                                add(
                                    pathOffset,
                                    RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                )
                            ) // poolAddress
                        )
                    }
                    default {
                        receiver := address()
                    }
                }
            }
            _swapUniswapV3PoolExactIn(amountIn, amountOutMinimum, payer, receiver, pathOffset, pathLength);
        }
        // iZi
        else if (poolId == IZI_ID) {
            address receiver;
            assembly {
                switch lt(pathLength, MAX_SINGLE_LENGTH_UNOSWAP_HIGH) // see swapExactIn
                case 1 {
                    receiver := address()
                }
                default {
                    let nextId := and(calldataload(add(pathOffset, 34)), UINT8_MASK) // SKIP_LENGTH_UNISWAP - 10
                    switch gt(nextId, 99)
                    case 1 {
                        receiver := shr(
                            96,
                            calldataload(
                                add(
                                    pathOffset,
                                    RECEIVER_OFFSET_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                )
                            ) // poolAddress
                        )
                    }
                    default {
                        receiver := address()
                    }
                }
            }
            _swapIZIPoolExactIn(uint128(amountIn), amountOutMinimum, payer, receiver, pathOffset, pathLength);
        }
        // uniswapV2 types
        else if (poolId < UNISWAP_V2_MAX_ID) {
            swapUniV2ExactInComplete(
                amountIn,
                amountOutMinimum, // we need to forward the amountMin
                payer,
                address(this), // receiver has to be this address
                true, // use flash swap
                pathOffset,
                pathLength
            );
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert(0, 0x4)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
