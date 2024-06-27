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

    // fusionx
    function fusionXV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, FUSION_V3_FF_FACTORY)
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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, FUSION_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // agni
    function agniSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, AGNI_V3_FF_FACTORY)
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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, AGNI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // swapsicle
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

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
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // butter
    function butterSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external  {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, BUTTER_FF_FACTORY)
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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, BUTTER_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // cleo
    function ramsesV2SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external  {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, CLEO_FF_FACTORY)
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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, CLEO_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // methlab
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

            ////////////////////////////////////////////////////
            // Compute and validate pool address
            ////////////////////////////////////////////////////
            let s := mload(0x40)
            mstore(s, METHLAB_FF_FACTORY)
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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, METHLAB_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
        }
        clSwapCallback(amount0Delta, amount1Delta, tokenIn, tokenOut, path);
    }

    // iZi callbacks
    
    // zeroForOne = true
    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
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
            path
        );
    }

    // zeroForOne = false
    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(path.offset, 42))
            tokenOut := and(ADDRESS_MASK, shr(80, firstWord))

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
            mstore(add(p, 64), and(UINT16_MASK, shr(240, firstWord)))
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
            path
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
    * @param data path calldata
    */
    function clSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        address tokenIn,
        address tokenOut,
        bytes calldata data
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
                            data.offset,
                            sub(data.length, 20)) // last 20 bytes
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
                        data.offset,
                        sub(data.length, 52)) // last 52 bytes
                )
            )
            // skim address from calldata
            data.length := sub(data.length, 36)
            // assume a multihop if the calldata is longer than 66
            multihop := gt(data.length, 66)
            // use tradeId as tradetype
            tradeId := and(shr(88, calldataload(data.offset)) , UINT8_MASK)
        }
        if(isExactIn) {
            // if additional data is provided, we execute the swap
            if (multihop) {
                ////////////////////////////////////////////////////
                // continue swapping
                ////////////////////////////////////////////////////
                uint256 dexId;
                assembly {
                    data.offset := add(data.offset, 44)
                    data.length := sub(data.length, 44)
                    // fetch the next dexId
                    dexId := and(shr(80, calldataload(data.offset)), UINT8_MASK)
                }
                ////////////////////////////////////////////////////
                // We assume that the next swap is funded
                ////////////////////////////////////////////////////
                amountReceived = swapExactIn(amountReceived, dexId, address(this), address(this), data);
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
                        tokenOut := shr(96, calldataload(add(data.offset, sub(data.length, 22))))
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
                (maximumAmount, lenderId) = getPayConfig(data);
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
            (uint256 payType, uint8 lenderId) = getPayConfig(data);
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
                    data.offset := add(data.offset, 44)
                    data.length := sub(data.length, 44)
                }
                swapExactOutInternal(
                    amountToPay,
                    maximumAmount,
                    payer,
                    msg.sender,
                    data
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


    // The uniswapV2 style callback for fusionX
    function FusionXCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_FLASH_LOAN)
                revert (0, 0x4)
            }
            // fetch tokens
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(data.offset)))
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
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
            mstore(ptr, FUSION_V2_FF_FACTORY)
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), CODE_HASH_FUSION_V2)

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
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, data);
    }

    // The uniswapV2 style callback for Merchant Moe
    function moeCall(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // fetch tokens
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(data.offset)))
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
            let ptr := mload(0x40)
            // selector for getPair(address,address)
            mstore(ptr, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)

            // call to collateralToken, this will always succeed due
            // to the immutable call target
            pop(staticcall(gas(), MERCHANT_MOE_FACTORY, ptr, 0x48, ptr, 0x20))

            // verify that the caller is a v2 type pool
            if xor(and(ADDRESS_MASK, mload(ptr)), caller()) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }
            // revert if sender param is not this address
            if xor(sender, address()) { 
                mstore(0, INVALID_CALLER)
                revert (0, 0x4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, data);
    }

    // The uniswapV2 style callback for Velocimeter, Cleopatra V1 and Stratum
    function hook(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        uint256 tradeId;
        address tokenIn;
        address tokenOut;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            // fetch tokens
            let firstWord := calldataload(data.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            let dexId := and(shr(80, firstWord), UINT8_MASK) // swap pool dexId
            tradeId := and(shr(88, firstWord), UINT8_MASK) // interaction dexId
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
            let ptr := mload(0x40)
            let pair
            switch dexId
            // Velo Volatile
            case 121 {
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
                mstore(ptr, VELO_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // Velo Stable
            case 122 {
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
                mstore(ptr, VELO_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // Cleo V1 Volatile
            case 123 {
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
                mstore(ptr, CLEO_V1_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // Cleo V1 Stable
            case 124 {
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
                mstore(ptr, CLEO_V1_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // Stratum Volatile
            case 125 {
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
                mstore(ptr, STRATUM_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
            }
            // 126: Stratum Stable
            default {
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
                mstore(ptr, STRATUM_FF_FACTORY)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(ptr, 0x55))
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
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, data);
    }

    /**
     * Flash swap callback for all UniV2 and Solidly type DEXs
     * @param amount0 amount of token0 received
     * @param amount1 amount of token1 received
     * @param data path calldata
     */
    function _v2StyleCallback(
        uint256 amount0,
        uint256 amount1,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) private {
        uint256 tradeId;
        uint256 maxAmount;
        uint256 amountReceived;
        address payer;
        bool multihop;
        uint256 amountToPay;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
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
                            data.offset,
                            sub(data.length, 20)) // last 20 bytes
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
                        data.offset,
                        sub(data.length, 52)) // last 52 bytes
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
            data.length := sub(data.length, 52)
            // assume a multihop if the calldata is longer than 64
            multihop := gt(data.length, 64)
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
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                ////////////////////////////////////////////////////
                // Note that for Uni V2 flash swaps, the receiver has
                // to be this contract. As such, we have to pre-fund 
                // the next swap
                ////////////////////////////////////////////////////
                uint256 dexId = _preFundTrade(address(this), amountReceived, data);
                // continue swapping
                amountReceived = swapExactIn(amountReceived, dexId, address(this), address(this), data);
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
                        tokenOut := shr(96, calldataload(add(data.offset, sub(data.length, 22))))
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
                (uint256 payType, uint8 lenderId) = getPayConfig(data);
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
            (uint256 payType, uint8 lenderId) = getPayConfig(data);
            if(tradeId != 0) {
                // pay lender
                payToLender(tokenIn, payer, amountReceived, tradeId, lenderId);
            }
            assembly {
                tradeId := and(shr(80, calldataload(data.offset)), UINT8_MASK) // swap pool identifier
            }
            // calculte amountIn (note that tokenIn/out are read inverted at the top)
            amountToPay = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, amountReceived, tradeId);
            // either initiate the next swap or pay
            if (multihop) {
                assembly {
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                swapExactOutInternal(amountToPay, maxAmount, payer, msg.sender, data);
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
     * @param path path calldata
     */
    function swapExactOutInternal(
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        address receiver,
        bytes calldata path
    ) internal {
        // fetch the pool identifier from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (poolId < 49) {
            _swapUniswapV3PoolExactOut(
                -int256(amountOut),
                maxIn,
                payer,
                receiver,
                path
            );
        }
        // iZi
        else if (poolId == 49) {
            _swapIZIPoolExactOut(
                uint128(amountOut),
                maxIn,
                payer,
                receiver,
                path
            );
        // uniswapV2 style
        } else if (poolId < 150) {
            address tokenIn;
            uint256 amountIn;
            address pair;
            address tokenOut;
            assembly {
                tokenOut := shr(96, calldataload(path.offset))
                tokenIn := shr(96, calldataload(add(path.offset, 42)))
                pair := shr(96, calldataload(add(path.offset, 22)))
            }
            ////////////////////////////////////////////////////
            // We calculate the required amount for the next swap
            ////////////////////////////////////////////////////
            amountIn = getV2AmountInDirect(pair, tokenIn, tokenOut, amountOut, poolId);
            
            ////////////////////////////////////////////////////
            // If the path includes more pairs, we nest another exact out swap
            // The funds of this exact out swap are sent to the pair
            // This is done by re-calling this same function after skimming the
            // data parameter by the leading token config 
            ////////////////////////////////////////////////////
            if(path.length > 64) {
                // remove the last token from the path
                assembly {
                    path.offset := add(path.offset, 42)
                    path.length := sub(path.length, 42)
                }
                swapExactOutInternal(
                    amountIn,
                    maxIn,
                    payer,
                    pair,
                    path
                );
            } 
            ////////////////////////////////////////////////////
            // Otherwise, we6 pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                (uint256 payType, uint8 lenderId) = getPayConfig(path);
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
                path
            );
        // special case: Moe LB, no flash swaps, recursive nesting is applied
        } else if (poolId == 151) {
            address tokenIn;
            uint256 amountIn;
            bool swapForY;
            address pair;
            {
                address tokenOut;
                assembly {
                    tokenOut := shr(96, calldataload(path.offset))
                    tokenIn := shr(96, calldataload(add(path.offset, 42)))
                    pair := shr(96, calldataload(add(path.offset, 22)))
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
            if(path.length > 65) { // limit is 20+1+1+20+20+2
                // remove the last token from the path
                assembly {
                    path.offset := add(path.offset, 42)
                    path.length := sub(path.length, 42)
                }
                swapExactOutInternal(
                    amountIn,
                    maxIn,
                    payer,
                    pair,
                    path
                );
            } 
            ////////////////////////////////////////////////////
            // Otherwise, we6 pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                (uint256 payType, uint8 lenderId) = getPayConfig(path);
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
            ////////////////////////////////////////////////////
            // The swap is executed at the end and sends 
            // the funds to the receiver addresss
            ////////////////////////////////////////////////////
            swapLBexactOut(pair, swapForY, amountOut, receiver);
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
     * @param path path calldata
     */
    function flashSwapExactOutInternal(
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        bytes calldata path
    ) internal {
        // fetch the pool identifier from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (poolId < 49) {
            _swapUniswapV3PoolExactOut(
                -int256(amountOut),
                maxIn,
                payer,
                address(this),
                path
            );
        }
        // iZi
        else if (poolId == 49) {
            _swapIZIPoolExactOut(
                uint128(amountOut),
                maxIn,
                payer,
                address(this),
                path
            );
        // uniswapV2 style
        } else if (poolId < 150) {
            address tokenOut;
            address tokenIn;
            address pair;
            assembly {
                tokenOut := and(ADDRESS_MASK, shr(96, calldataload(path.offset)))
                tokenIn := and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 42))))
                pair := and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 22))))
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
                path
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
        bytes calldata path
    ) internal {
        // fetch the pool poolId from the path
        uint256 poolId;
        assembly {
            poolId := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 types
        if (poolId < 49) {
            address reciever;
            assembly {
                switch lt(path.length, 67) // see swapExactIn
                case 1 { reciever := address()}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
                    case 1 {
                        reciever := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        66 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
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
                path.length,
                path
            );
        }
        // iZi
        else if (poolId == 49) {
            address reciever;
            assembly {
                switch lt(path.length, 67) // see swapExactIn
                case 1 { reciever := address()}
                default {
                    let nextId := and(shr(80, calldataload(add(path.offset, 44))), UINT8_MASK)
                    switch gt(nextId, 99) 
                    case 1 {
                        reciever := and(
                            ADDRESS_MASK,
                            shr(
                                96,
                                calldataload(
                                    add(
                                        path.offset,
                                        66 // 20 + 2 + 20 + 2 + 20 + 2 [poolAddress starts here]
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
                path.length,
                path
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
                path
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
    function getPayConfig(bytes calldata data) internal pure returns(uint256 payType, uint8 lenderId){
        assembly {
            let lastWord := calldataload(
                sub(
                    add(data.length, data.offset),
                    32
                )
            )
            lenderId := and(shr(8, lastWord), UINT8_MASK)
            payType := and(lastWord, UINT8_MASK)
        }
    }

    function getLender(bytes calldata data) internal pure returns(uint8 lenderId){
        assembly {
            lenderId := and(
                shr(
                    8,
                    calldataload(
                    sub(
                        add(data.length, data.offset),
                        32
                    )
                    )
                ),
                UINT8_MASK
             )
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
                _borrow(token, payer, receiver, value, paymentType, lenderId);
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
