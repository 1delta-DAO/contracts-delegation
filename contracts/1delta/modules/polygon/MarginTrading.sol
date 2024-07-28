// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {BaseSwapper} from "./BaseSwapper.sol";
import {BaseLending} from "./BaseLending.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract MarginTrading is BaseSwapper, BaseLending {
    // errors
    error NoBalance();

    uint256 internal constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

    constructor() BaseSwapper() BaseLending() {}

    // swapsicle
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        uint256 pathOffset;
        uint256 pathLength;
        assembly {
            pathOffset := path.offset
            pathLength := path.length
            let firstWord := calldataload(pathOffset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(pathOffset, 32))
            tokenOut := and(ADDRESS_MASK, firstWord)

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, ALGEBRA_V3_FF_DEPLOYER)
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
            mstore(p, keccak256(p, 64))
            p := add(p, 32)
            mstore(p, ALGEBRA_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, pathOffset, pathLength);
    }

    // uniswap, retro, sushi
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        uint256 pathOffset;
        uint256 pathLength;
        assembly {
            pathOffset := path.offset
            pathLength := path.length
            let firstWord := calldataload(pathOffset)
            let dexId := and(UINT8_MASK, shr(80, firstWord))
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(pathOffset, 32))
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
            case 1 {
                mstore(s, RETRO_FF_FACTORY)
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
                mstore(p, RETRO_POOL_INIT_CODE_HASH)
            }
            case 2 {
                mstore(s, SUSHI_V3_FF_DEPLOYER)
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
                mstore(p, SUSHI_POOL_INIT_CODE_HASH)
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
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, pathOffset, pathLength);
    }

    // iZi callbacks
    
    // zeroForOne = true
    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        uint256 pathOffset;
        uint256 pathLength;
        assembly {
            pathOffset := path.offset
            pathLength := path.length
            let firstWord := calldataload(pathOffset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(pathOffset, 32))
            
            tokenOut := and(ADDRESS_MASK, firstWord)

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, IZI_FF_FACTORY)
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
            mstore(p, IZI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(
            -int256(x),
            int256(y),
            tokenIn,
            tokenOut,
            pathOffset,
            pathLength
        );
    }

    // zeroForOne = false
    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        uint256 pathOffset;
        uint256 pathLength;
        assembly {
            pathOffset := path.offset
            pathLength := path.length
            let firstWord := calldataload(pathOffset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(pathOffset, 32))
            tokenOut := and(ADDRESS_MASK, firstWord)

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            let p := s
            mstore(p, IZI_FF_FACTORY)
            p := add(p, 21)
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
            mstore(p, IZI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(
            int256(x),
            -int256(y),
            tokenIn,
            tokenOut,
            pathOffset,
            pathLength
        );
    }

   /**
    * The uniswapV3 style callback
    * 
    * PATH IDENTIFICATION
    * 
    * [actionId]
    * 0: base swap - just pay the pool
    * 1: repay stable
    * 2: repay variable
    * 3: deposit
    * 
    * [end flag]
    * 1: borrow stable
    * 2: borrow variable
    * 3: withdraw
    * 0: pay from provided address (caller or this contract)
    * 
    * @param amount0Delta delta of token0, if positive, we have to pay, if negative, we received
    * @param amount1Delta delta of token1, if positive, we have to pay, if negative, we received
    */
    function clSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        address tokenIn,
        address tokenOut,
        uint256 pathOffset,
        uint256 pathLength
    ) private {
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
            // It is represented by the lsat 20 bytes of the path
            ////////////////////////////////////////////////////
            payer := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(
                        add(
                            pathOffset,
                            sub(pathLength, 20)) // last 20 bytes
                        )
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
                        pathOffset,
                        sub(pathLength, 52)) // last 52 bytes
                )
            )
            // skim address from calldata
            pathLength := sub(pathLength, 36)
            // assume a multihop if the calldata is longer than 66
            multihop := gt(pathLength, 66)
            // use tradeId as tradetype
            tradeId := and(shr(88, calldataload(pathOffset)) , UINT8_MASK)
        }
        if(isExactIn) {
            // if additional data is provided, we execute the swap
            if (multihop) {
                ////////////////////////////////////////////////////
                // continue swapping
                ////////////////////////////////////////////////////
                uint256 dexId;
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                    // fetch the next dexId
                    dexId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
                }
                ////////////////////////////////////////////////////
                // We assume that the next swap is funded
                ////////////////////////////////////////////////////
                amountReceived = swapExactIn(amountReceived, dexId, address(this), address(this), pathOffset, pathLength);
                // check slippage since we will not be able to
                // get the output amout outside of this scope
                assembly {
                    if lt(amountReceived, maximumAmount) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }

            ////////////////////////////////////////////////////
            // Exact input base swap handling
            ////////////////////////////////////////////////////
            if (tradeId != 0) {
                // get token out
                assembly {
                    switch multihop
                    case 1 {
                        tokenOut := shr(96, calldataload(add(pathOffset, sub(pathLength, 22))))
                    }
                    default {
                        // slippage check since we do not do a nested swap in this case
                        if lt(amountReceived, maximumAmount) {
                            mstore(0, SLIPPAGE)
                            revert (0, 0x4)
                        }
                    }
                }
                // slice out the end flag, paymentId overrides maximum amount
                uint8 lenderId;
                (maximumAmount, lenderId) = getPayConfigFromCalldata(pathOffset, pathLength);
                payToLender(tokenOut, payer, amountReceived, tradeId, lenderId);
                // pay the pool
                handlePayPool(
                    tokenIn,
                    payer,
                    msg.sender,
                    maximumAmount,
                    amountToPay,
                    lenderId
                );
            } else {
                payConventional(tokenIn, payer, msg.sender, amountToPay);
            }
        } 
        ////////////////////////////////////////////////////
        // Exact output swap
        ////////////////////////////////////////////////////
        else {
            (uint256 payType, uint8 lenderId) = getPayConfigFromCalldata(pathOffset, pathLength);
            // we check if we have to deposit or repay in the callback
            if(tradeId != 0) {
                payToLender(tokenIn, payer, amountReceived, tradeId, lenderId);
            }
            // multihop if required
            if (multihop) {
                ////////////////////////////////////////////////////
                // continue swapping
                ////////////////////////////////////////////////////
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                }
                swapExactOutInternal(
                    amountToPay,
                    maximumAmount,
                    payer,
                    msg.sender,
                    pathOffset,
                    pathLength
                );
            } else {
                // check slippage
                assembly {
                    if lt(maximumAmount, amountToPay) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
                ////////////////////////////////////////////////////
                // pay the pool
                ////////////////////////////////////////////////////
                handlePayPool(
                    tokenOut,
                    payer,
                    msg.sender,
                    payType,
                    amountToPay,
                    lenderId
                );
                return;
            }
        }
    }

    // The uniswapV2 style callback for exact forks
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 pathOffset;
        uint256 pathLength;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_FLASH_LOAN)
                revert (0, 0x4)
            }
            pathOffset := data.offset
            pathLength := data.length
            // fetch tokens
            let firstWord := calldataload(pathOffset)
            let pId := and(UINT8_MASK, shr(80, firstWord)) 
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tokenOut := and(ADDRESS_MASK, calldataload(add(pathOffset, 32)))
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
            case 101 {
                mstore(ptr, QUICK_V2_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_UNI_V2)
            }
            case 102 {
                mstore(ptr, SUSHI_V2_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_SUSHI_V2)
            }
            case 103 {
                mstore(ptr, DFYN_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_DFYN)
            }
            case 104 {
                mstore(ptr, POLYCAT_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_POLYCAT)
            }
            case 106 {
                mstore(ptr, COMETH_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_COMETH)
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
                revert (0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, pathOffset, pathLength);
    }


    // The uniswapV2 style callback for waultswap
    function waultSwapCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 pathOffset;
        uint256 pathLength;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_FLASH_LOAN)
                revert (0, 0x4)
            }
            pathOffset := data.offset
            pathLength := data.length
            // fetch tokens
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(pathOffset)))
            tokenOut := and(ADDRESS_MASK, calldataload(add(pathOffset, 32)))
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
            mstore(ptr, WAULTSWAP_FF_FACTORY)
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), CODE_HASH_WAULTSWAP)

            // verify that the caller is a v2 type pool
            if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_CALLER)
                revert (0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, pathOffset, pathLength);
    }

    // The uniswapV2 style callback for apeswap
    function apeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 pathOffset;
        uint256 pathLength;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_FLASH_LOAN)
                revert (0, 0x4)
            }
            pathOffset := data.offset
            pathLength := data.length
            // fetch tokens
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(pathOffset)))
            tokenOut := and(ADDRESS_MASK, calldataload(add(pathOffset, 32)))
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
            mstore(ptr, APESWAP_FF_FACTORY)
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), CODE_HASH_APESWAP)

            // verify that the caller is a v2 type pool
            if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_CALLER)
                revert (0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, pathOffset, pathLength);
    }

    // The uniswapV2 style callback for solidly forks
    function hook(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        uint256 tradeId;
        address tokenIn;
        address tokenOut;  
        uint256 pathOffset;
        uint256 pathLength;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_FLASH_LOAN)
                revert (0, 0x4)
            }
            pathOffset := data.offset
            pathLength := data.length
            // fetch tokens
            let firstWord := calldataload(pathOffset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            let dexId := and(shr(80, firstWord), UINT8_MASK) // swap pool dexId
            tradeId := and(shr(88, firstWord), UINT8_MASK) // interaction dexId
            tokenOut := and(ADDRESS_MASK, calldataload(add(pathOffset, 32)))
            let ptr := mload(0x40)
            let pair
            switch dexId
            // Dystopia Volatile
            case 120 {
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(add(ptr, 0x14), tokenIn)
                    mstore(ptr, tokenOut)
                }
                default {
                    mstore(add(ptr, 0x14), tokenOut)
                    mstore(ptr, tokenIn)
                }
                mstore8(add(ptr, 0x34), 0)
                let salt := keccak256(add(ptr, 0x0C), 0x29)
                mstore(ptr, DYSTOPIA_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_DYSTOPIA)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // Dystopia Stable
            case 135 {
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(add(ptr, 0x14), tokenIn)
                    mstore(ptr, tokenOut)
                }
                default {
                    mstore(add(ptr, 0x14), tokenOut)
                    mstore(ptr, tokenIn)
                }
                mstore8(add(ptr, 0x34), 1)
                let salt := keccak256(add(ptr, 0x0C), 0x29)
                mstore(ptr, DYSTOPIA_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CODE_HASH_DYSTOPIA)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            default {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }

            // verify that the caller is a v2 type pool
            if xor(pair, caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_CALLER)
                revert (0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, pathOffset, pathLength);
    }

    /**
     * Flash swap callback for all UniV2 and Solidly type DEXs
     * @param amount0 amount of token0 received
     * @param amount1 amount of token1 received
     */
    function _v2StyleCallback(
        uint256 amount0,
        uint256 amount1,
        address tokenIn,
        address tokenOut,
        uint256 pathOffset,
        uint256 pathLength
    ) private {
        uint256 tradeId;
        uint256 maxAmount;
        uint256 amountReceived;
        address payer;
        bool multihop;
        uint256 amountToPay;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(pathOffset)
            tradeId := and(shr(88, firstWord), UINT8_MASK) // interaction identifier
            ////////////////////////////////////////////////////
            // We fetch the original initiator of the swap function
            // It is represented by the last 20 bytes of the path
            ////////////////////////////////////////////////////
            payer := and(
                ADDRESS_MASK,
                shr(
                    96,
                    calldataload(
                        add(
                            pathOffset,
                            sub(pathLength, 20)) // last 20 bytes
                        )
                )
            )
            ////////////////////////////////////////////////////
            // amount [128|128] starting at the 52th byte
            // from the right as [maximum|amountToPay]
            // here we fetch the entire amount and decompose it
            ////////////////////////////////////////////////////
            maxAmount := calldataload(
                    add(
                        pathOffset,
                        sub(pathLength, 52)) // last 52 bytes
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
        ////////////////////////////////////////////////////
        // exactIn is used when `amountToPay` is nonzero
        ////////////////////////////////////////////////////
        if(amountToPay != 0) {
            if (multihop) {
                // we need to swap to the token that we want to supply
                // the router returns the amount received that we can validate against
                // throught the `maxAmount`
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                }
                ////////////////////////////////////////////////////
                // Note that for Uni V2 flash swaps, the receiver has
                // to be this contract. As such, we have to pre-fund 
                // the next swap
                ////////////////////////////////////////////////////
                uint256 dexId = _preFundTrade(address(this), amountReceived, pathOffset);
                // continue swapping
                amountReceived = swapExactIn(amountReceived, dexId, address(this), address(this), pathOffset, pathLength);
                // store result in cache
                // if(maxAmount > tradeId) revert Slippage();
                assembly {
                    if lt(amountReceived, maxAmount) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }
            if (tradeId != 0) {
                assembly {
                    switch multihop 
                    case 1 {
                        // get tokenOut
                        // note that for multihops this is required as the tokenOut at the
                        // beginning of this call is just one in a swap step
                        tokenOut := shr(96, calldataload(add(pathOffset, sub(pathLength, 22))))
                    }
                    default {
                        // we check the slippage here since we skip it 
                        // in the upper block
                        if lt(amountReceived, maxAmount) {
                            mstore(0, SLIPPAGE)
                            revert (0, 0x4)
                        }
                    }
                }
                (uint256 payType, uint8 lenderId) = getPayConfigFromCalldata(pathOffset, pathLength);
                // pay lender
                payToLender(tokenOut, payer, amountReceived, tradeId, lenderId);
                // pay the pool
                handlePayPool(
                    tokenIn,
                    payer,
                    msg.sender,
                    payType,
                    amountToPay,
                    lenderId
                );
             } else {
                payConventional(tokenIn, payer, msg.sender, amountToPay);
             }
        } else {
            (uint256 payType, uint8 lenderId) = getPayConfigFromCalldata(pathOffset, pathLength);
            if(tradeId != 0) {
                // pay lender
                payToLender(tokenIn, payer, amountReceived, tradeId, lenderId);
            }
            uint256 feeDenom;
            assembly {
                //  | actId | pId | pair | feeDenom
                //  | 20    | 21  |22-42 | 42-44
                // load so that feeDenom is in the lower bytes
                feeDenom := calldataload(add(pathOffset, 12))
                tradeId := and(shr(176, feeDenom), UINT8_MASK) // swap pool identifier
                feeDenom := and(feeDenom, UINT16_MASK) // mask denom
            }
            // calculte amountIn (note that tokenIn/out are read inverted at the top)
            amountToPay = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, amountReceived, feeDenom, tradeId);
            // either initiate the next swap or pay
            if (multihop) {
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                }
                swapExactOutInternal(amountToPay, maxAmount, payer, msg.sender, pathOffset, pathLength);
            } else {
                // if(maxAmount < amountToPay) revert Slippage();
                assembly {
                    if lt(maxAmount, amountToPay) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
                // pay the pool
                handlePayPool(
                    tokenOut,
                    payer,
                    msg.sender,
                    payType,
                    amountToPay,
                    lenderId
                );
            }
            return;
        }
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
        if (poolId < 49) {
            _swapUniswapV3PoolExactOut(
                -int256(amountOut),
                maxIn,
                payer,
                receiver,
                pathOffset,
                pathLength
            );
        }
        // iZi
        else if (poolId == 49) {
            _swapIZIPoolExactOut(
                uint128(amountOut),
                maxIn,
                payer,
                receiver,
                pathOffset,
                pathLength
            );
        // uniswapV2 style
        } else if (poolId < 150) {
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
                    feeDenom := and(UINT16_MASK, shr(80, calldataload(add(pathOffset, 22))))
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
            if(pathLength > MAX_SINGLE_LENGTH_UNOSWAP) {
                // remove the last token from the path
                assembly {
                    pathOffset := add(pathOffset, SKIP_LENGTH_UNOSWAP)
                    pathLength := sub(pathLength, SKIP_LENGTH_UNOSWAP)
                }
                swapExactOutInternal(
                    amountIn,
                    maxIn,
                    payer,
                    pair,
                    pathOffset,
                    pathLength
                );
            } 
            ////////////////////////////////////////////////////
            // Otherwise, we6 pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                (uint256 payType, uint8 lenderId) = getPayConfigFromCalldata(pathOffset, pathLength);
                // pay the pool
                handlePayPool(
                    tokenIn,
                    payer, // prevents sload if desired
                    pair,
                    payType,
                    amountIn,
                    lenderId
                );
                // if(maxIn < amountIn) revert Slippage();
                assembly {
                    if lt(maxIn, amountIn) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
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
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert (0, 0x4)
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
    function flashSwapExactOutInternal(
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        uint256 pathOffset,
        uint256 pathLength 
    ) internal {
        // fetch the pool identifier from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (poolId < 49) {
            _swapUniswapV3PoolExactOut(
                -int256(amountOut),
                maxIn,
                payer,
                address(this),
                pathOffset,
                pathLength
            );
        }
        // iZi
        else if (poolId == 49) {
            _swapIZIPoolExactOut(
                uint128(amountOut),
                maxIn,
                payer,
                address(this),
                pathOffset,
                pathLength
            );
        // uniswapV2 style
        } else if (poolId < 150) {
            address tokenOut;
            address tokenIn;
            address pair;
            assembly {
                tokenOut := and(ADDRESS_MASK, shr(96, calldataload(pathOffset)))
                tokenIn := and(ADDRESS_MASK, shr(96, calldataload(add(pathOffset, SKIP_LENGTH_UNOSWAP))))
                pair := and(ADDRESS_MASK, shr(96, calldataload(add(pathOffset, 22))))
            }
            _swapV2StyleExactOut(
                tokenIn,
                tokenOut,
                pair,
                amountOut,
                maxIn,
                payer,
                address(this),
                true,
                pathOffset,
                pathLength
            );
        } else {
            assembly {
                mstore(0, INVALID_DEX)
                revert (0, 0x4)
            }
        }
    }

    // Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactInInternal(
        uint256 amountIn,
        uint256 amountOutMinimum,
        address payer,
        uint256 pathOffset,
        uint256 pathLength 
    ) internal {
        // fetch the pool poolId from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(pathOffset)), UINT8_MASK)
        }
        // uniswapV3 types
        if (poolId < 49) {
            address reciever;
            assembly {
                switch lt(pathLength, 67) // see swapExactIn
                case 1 { reciever := address()}
                default {
                    let nextId := and(
                        shr(80, 
                        calldataload(add(pathOffset, SKIP_LENGTH_UNOSWAP))), //
                        UINT8_MASK
                    )
                    switch gt(nextId, 99) 
                    case 1 {
                        reciever := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                        )
                    }
                    default {
                        reciever := address()
                    }
                }
            }
            _swapUniswapV3PoolExactIn(
                amountIn,
                amountOutMinimum,
                payer,
                reciever,
                pathOffset,
                pathLength
            );
        }
        // iZi
        else if (poolId == 49) {
            address reciever;
            assembly {
                switch lt(pathLength, 67) // see swapExactIn
                case 1 { reciever := address()}
                default {
                    let nextId := and(
                        shr(80, 
                        calldataload(add(pathOffset, SKIP_LENGTH_UNOSWAP))), //
                        UINT8_MASK
                    )
                    switch gt(nextId, 99) 
                    case 1 {
                        reciever := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        pathOffset,
                                        MAX_SINGLE_LENGTH_UNOSWAP // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
                                    )
                                ) // poolAddress
                            )
                        )
                    }
                    default {
                        reciever := address()
                    }
                }
            }
            _swapIZIPoolExactIn(
                uint128(amountIn),
                amountOutMinimum,
                payer,
                reciever,
                pathOffset,
                pathLength
            );
        }
        // uniswapV2 types
        else if (poolId < 150) {
            swapUniV2ExactInComplete(
                amountIn,
                amountOutMinimum, // we need to forward the amountMin
                payer,
                address(this), // receiver has to be this address
                true, // use flash swap
                pathOffset,
                pathLength
            );
        }
        else {
            assembly {
                mstore(0, INVALID_DEX)
                revert (0, 0x4)
            }
        }
    }

    /// @dev gets leder and pay config - the assumption is that the last byte is the payType
    ///      and the second last is the lenderId
    function getPayConfigFromCalldata(uint256 offset, uint256 length) internal pure returns(uint256 payType, uint8 lenderId){
        assembly {
            let lastWord := calldataload(
                sub(
                    add(offset, length),
                    32
                )
            )
            lenderId := and(shr(8, lastWord), UINT8_MASK)
            payType := and(lastWord, UINT8_MASK)
        }
    }

    /**
     * Handle a payment from payer to receiver via different channels
     * @param token The token to pay
     * @param payer The entity that must pay
     * @param receiver receiver address
     * @param paymentType payment identifier
     *                    1:    borrow stable
     *                    2:    borrow variable
     *                    3-7:  withdraw from lender
     *                    >7:   pay from wallet
     * @param value The amount to pay
     */
    function handlePayPool(
        address token,
        address payer,
        address receiver,
        uint256 paymentType,
        uint256 value,
        uint8 lenderId
    ) internal {
        if(paymentType < 8) {
            if (paymentType < 3) {
                // borrow and repay pool - tradeId matches interest rate mode (reverts within Aave when 0 is selected)
                _borrow(token, payer,  receiver, value, paymentType, lenderId);
            } else {
                // ids 3-7 are reserved
                _withdraw(token, payer, receiver, value, lenderId);
            } 
        } else {
            payConventional(token, payer, receiver, value);
        }
    }

    function payToLender(
        address token,
        address user,
        uint256 amount,
        uint256 payId,
        uint8 lenderId
     ) internal {
        if (payId == 3) {
            _deposit(token, user, amount, lenderId);
        } else { // otherwise it is the repay mode
            _repay(token, user, amount, payId, lenderId);
        }
     } 


    function payConventional(address underlying,address payer, address receiver, uint256 amount) internal {
        assembly {
            switch eq(payer, address())
            case 0 {
                let ptr := mload(0x40) // free memory pointer

                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), receiver)
                mstore(add(ptr, 0x44), amount)

                let success := call(gas(), underlying, 0, ptr, 0x64, ptr, 32)

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            default {
                let ptr := mload(0x40) // free memory pointer

                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amount)

                let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            iszero(lt(rdsize, 32)), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
        }
    }
}
