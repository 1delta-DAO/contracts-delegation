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
    error InvalidDex();

    uint256 internal constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

    constructor() BaseSwapper() BaseLending() {}

    /// @dev Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactIn(
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path
    ) external payable {
        flashSwapExactInInternal(amountIn, amountOutMinimum, path);
    }

    // Exact Output Swap - The path parameters determine the lending actions
    function flashSwapExactOut(
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path
    ) external payable {
        flashSwapExactOutInternal(amountOut, amountInMaximum, msg.sender, address(this), path);
    }

    // Exact Input Swap where the entire collateral amount is withdrawn - The path parameters determine the lending actions
    // if the collateral balance is zerp. the tx reverts
    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable {
        uint256 amountIn;
        {
            address tokenIn;    
            assembly {
                tokenIn := shr(96, calldataload(path.offset))
            }
            // fetch collateral balance
            amountIn = _callerCollateralBalance(tokenIn, getLender(path));
            if (amountIn == 0) revert NoBalance();
        }
        flashSwapExactInInternal(amountIn, amountOutMinimum, path);
    }

    // Exact Output Swap where the entire debt balacne is repaid - The path parameters determine the lending actions
    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable {
        uint256 amountOut;
        {
            address tokenOut;
            uint8 _identifier;
            // we need tokenIn together with lender id for he balance fetch
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord)
                _identifier := shr(88, firstWord)
            }   

            // determine output amount as respective debt balance
            if (_identifier == 5) amountOut = _variableDebtBalance(tokenOut, msg.sender, getLender(path));
            else amountOut = _stableDebtBalance(tokenOut, msg.sender, getLender(path));
            if (amountOut == 0) revert NoBalance();
        
            // fetch poolId - store it in _identifier
            assembly {
                _identifier := shr(64, calldataload(path.offset))
            }
        }

        flashSwapExactOutInternal(amountOut, amountInMaximum, msg.sender, address(this), path);
    }

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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, FUSION_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, AGNI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, BUTTER_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, CLEO_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, METHLAB_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, IZI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
            let fee := and(
                    shr(240, firstWord), 
                    UINT16_MASK
            ) // uniswapV3 type fee
            
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
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, IZI_POOL_INIT_CODE_HASH)
        
            ////////////////////////////////////////////////////
            // If the caller is not the calculated pool, we revert
            ////////////////////////////////////////////////////
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0, BAD_POOL)
                revert(0, 4)
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
    * [between pools if more than one]
    * 0: exact input swap
    * 1: exact output swap - flavored by the id given at the end of the path
    * 
    * [end flag]
    * 1: borrow stable
    * 2: borrow variable
    * 3: withdraw
    * 4: pay from cached address (spot)
    * 
    * [start flag (>1)]
    * 6: deposit exact in
    * 7: repay exact in stable
    * 8: repay exact in variable
    * 
    * 3: deposit exact out
    * 4: repay exact out stable
    * 5: repay exact out variable
    * 
    * @param amount0Delta delta of token0, if positive, we have to pay, if negative, we received
    * @param amount1Delta delta of token1, if positive, we have to pay, if negative, we received
    * @param _data path calldata
    */
    function clSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        address tokenIn,
        address tokenOut,
        bytes calldata _data
    ) private {
        uint256 tradeId;
        bool preventSelfPayment;
        address payer;
        uint256 maximumAmount;
        assembly {
            let firstWord := calldataload(_data.offset)
            tradeId := and(shr(80, firstWord), UINT8_MASK) 
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
                            _data.offset,
                            sub(_data.length, 20)) // last 20 bytes
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
                        _data.offset,
                        sub(_data.length, 52)) // last 52 bytes
                )
            )
            _data.length := sub(_data.length, 36) // skim address from calldata

            // use tradeId as tradetype
            tradeId := and(shr(88, firstWord) , UINT8_MASK)

            // 10 (11) means that we are paying from the cache in an exact input (output)
            // scenario                
            if eq(tradeId, 10) {
                preventSelfPayment := 1
                tradeId := 0
            }        
            if eq(tradeId, 11) {
                preventSelfPayment := 1
                tradeId := 1
            }
        }
        ////////////////////////////////////////////////////
        // Exact input base swap handling
        ////////////////////////////////////////////////////
        if (tradeId == 0) {
            // amountOut is needed for when we 
            // want to continue to swap
            uint256 amountOut;
            // assign the amount to pay to the local stack
            assembly {
                switch sgt(amount0Delta, 0)
                case 1 {
                    tradeId := amount0Delta
                    amountOut := sub(0, amount1Delta)
                }
                default {
                    tradeId := amount1Delta
                    amountOut := sub(0, amount0Delta)
                }
            }
            // of additional data is provided, we execute the swap
            if (_data.length > 66) {
                ////////////////////////////////////////////////////
                // continue swapping
                ////////////////////////////////////////////////////
                uint256 dexId;
                assembly {
                    _data.offset := add(_data.offset, 44)
                    _data.length := sub(_data.length, 44)
                    // fetch the next dexId
                    dexId := and(shr(80, calldataload(_data.offset)), UINT8_MASK)
                }
                ////////////////////////////////////////////////////
                // We assume that the next swap is funded
                ////////////////////////////////////////////////////
                amountOut = swapExactIn(amountOut, dexId, address(this), address(this), _data);
                assembly {
                    if lt(amountOut, maximumAmount) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
                
            }
            if(preventSelfPayment) _transferERC20TokensFrom(tokenIn, payer, msg.sender, tradeId);
            else _transferERC20Tokens(tokenIn, msg.sender, tradeId);
            return;
        }
        ////////////////////////////////////////////////////
        // Exact output swap
        // Can be
        //  - pulling from caller (cached)
        //  - paying from this address
        //  - borrow to pay
        //  - withdraw to pay
        ////////////////////////////////////////////////////
        else if (tradeId == 1) {
            // fetch amount that has to be paid to the pool
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            // either initiate the next swap or pay
            if (_data.length > 66) {
                assembly {
                    _data.offset := add(_data.offset, 44)
                    _data.length := sub(_data.length, 44)
                }
                swapExactOutInternal(amountToPay, maximumAmount, payer, msg.sender, _data);
            } else {
                // fetch payment config - ignored for paying firectly
                (uint256 payType, uint8 lenderId) = getPayConfig(_data);
                // pay the pool
                handlePayPool(
                    tokenOut,
                    preventSelfPayment ? payer : address(this),
                    msg.sender,
                    payType,
                    amountToPay,
                    lenderId
                );
                assembly {
                    if lt(maximumAmount, amountToPay) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }
            return;
        }
        ////////////////////////////////////////////////////
        // Margin operations have ids larger than 1
        ////////////////////////////////////////////////////
        else {
            // exact in
            if (tradeId > 5) {
                uint256 amountToRepayToPool;
                uint256 amountToSwap;
                assembly {
                    switch sgt(amount0Delta, 0)
                    case 1 {
                        amountToRepayToPool := amount0Delta
                        amountToSwap := sub(0, amount1Delta)
                    }
                    default {
                        amountToRepayToPool := amount1Delta
                        amountToSwap := sub(0, amount0Delta)
                    }
                }
                ////////////////////////////////////////////////////
                // If the path is longer than 2 addresses, uint16, 3 uint8s
                // We try to continue to swap
                ////////////////////////////////////////////////////
                if (_data.length > 66) { 
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    uint256 dexId;
                    assembly {
                        _data.offset := add(_data.offset, 44)
                        _data.length := sub(_data.length, 44)
                        // fetch the next dexId
                        dexId := and(shr(80, calldataload(_data.offset)), UINT8_MASK)
                    }
                    amountToSwap = swapExactIn(amountToSwap, dexId, address(this), address(this), _data);
                    // re-assign tokenOut
                    assembly {
                        tokenOut := shr(96, calldataload(add(_data.offset, sub(_data.length, 22))))
                    }
                }
                // check slippage
                assembly {
                    if lt(amountToSwap, maximumAmount) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
                // slice out the end flag, paymentId overrides maximum amount
                uint8 lenderId;
                (maximumAmount, lenderId) = getPayConfig(_data);

                // 6 is mint / deposit
                if (tradeId == 6) {
                    _deposit(tokenOut, payer, amountToSwap, lenderId);
                } else {
                    // tradeId minus 6 yields the interest rate mode
                    tradeId -= 6;
                    _repay(tokenOut, payer, amountToSwap, tradeId, lenderId);
                }
                // pay the pool
                handlePayPool(
                    tokenIn,
                    payer,
                    msg.sender,
                    maximumAmount,
                    amountToRepayToPool,
                    lenderId
                );
            } else {
                (uint256 payType, uint8 lenderId) = getPayConfig(_data);
                // exact out
                uint256 amountInLastPool;
                {
                    uint256 amountToSupply;
                    assembly {
                        switch sgt(amount0Delta, 0)
                        case 1 {
                            amountInLastPool := amount0Delta
                            amountToSupply := sub(0, amount1Delta)
                        }
                        default {
                            amountInLastPool := amount1Delta
                            amountToSupply := sub(0, amount0Delta)
                        }
                    }
                    // 3 is deposit
                    if (tradeId == 3) {
                        _deposit(tokenIn, payer, amountToSupply, lenderId);
                    } else {
                        // 4, 5 are repay - subtracting 3 yields the interest rate mode
                        tradeId -= 3;
                        _repay(tokenIn, payer, amountToSupply, tradeId, lenderId);
                    }
                }

                // multihop if required
                if (_data.length > 66) {
                    ////////////////////////////////////////////////////
                    // continue swapping
                    ////////////////////////////////////////////////////
                    assembly {
                        _data.offset := add(_data.offset, 44)
                        _data.length := sub(_data.length, 44)
                    }
                    swapExactOutInternal(
                        amountInLastPool,
                        maximumAmount,
                        payer,
                        msg.sender,
                        _data
                    );
                } else {
                    ////////////////////////////////////////////////////
                    // pay the pool
                    ////////////////////////////////////////////////////
                    handlePayPool(
                        tokenOut,
                        payer,
                        msg.sender,
                        payType,
                        amountInLastPool,
                        lenderId
                    );
                    // check slippage
                    assembly {
                        if lt(maximumAmount, amountInLastPool) {
                            mstore(0, SLIPPAGE)
                            revert (0, 0x4)
                        }
                    }
                }
            }
            return;
        }
    }


    // The uniswapV2 style callback for fusionX
    function FusionXCall(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(data.offset)))
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
            zeroForOne := lt(tokenIn, tokenOut)
            let ptr := mload(0x40)
            switch zeroForOne
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
                mstore(0, BAD_POOL)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, zeroForOne, data);
    }

    // The uniswapV2 style callback for Merchant Moe
    function moeCall(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            tokenIn := and(ADDRESS_MASK, shr(96, calldataload(data.offset)))
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
            zeroForOne := lt(tokenIn, tokenOut)
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
                revert(0, 4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, zeroForOne, data);
    }

    // The uniswapV2 style callback for Velocimeter, Cleopatra V1 and Stratum
    function hook(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        uint256 tradeId;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            let dexId := and(shr(80, firstWord), UINT8_MASK) // swap pool dexId
            tradeId := and(shr(88, firstWord), UINT8_MASK) // interaction dexId
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 42))))
            zeroForOne := lt(tokenIn, tokenOut)
            let ptr := mload(0x40)
            let pair
            switch dexId
            // Velo Volatile
            case 121 {
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                switch zeroForOne
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
                mstore(0, BAD_POOL)
                revert(0, 4)
            }
        }
        _v2StyleCallback(amount0, amount1, tokenIn, tokenOut, zeroForOne, data);
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
        bool zeroForOne,
        bytes calldata data
    ) private {
        uint256 tradeId;
        bool preventSelfPayment;
        uint256 refAmount;
        address payer;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
            let identifier := and(shr(80, firstWord), UINT8_MASK) // swap pool identifier
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
            // refAmount [128|128] starting at the 52th byte
            // from the right as [maximum|amountIn]
            ////////////////////////////////////////////////////
            refAmount := calldataload(
                    add(
                        data.offset,
                        sub(data.length, 52)) // last 52 bytes
            )

            data.length := sub(data.length, 52) // skim address from calldata

            // use tradeId as tradetype
            tradeId := and(shr(88, firstWord) , UINT8_MASK)

            // 10 (11) means that we are paying from the cache in an exact input (output)
            // scenario                
            if eq(tradeId, 10) {
                preventSelfPayment := 1
                tradeId := 0
            }        
            if eq(tradeId, 11) {
                preventSelfPayment := 1
                tradeId := 1
            }
        }
        // exact in is handled outside a callback
        // however, if calldata is provided, the pool is paid here
        if (tradeId == 0) {
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through the cache
            uint256 amountToSwap;
            assembly {
                switch zeroForOne
                case 1 {
                    amountToSwap := amount1
                }
                default {
                    amountToSwap := amount0
                }
            }
            if (data.length > 64) {
                // we need to swap to the token that we want to supply
                // the router returns the amount received that we can validate against
                // throught the `refAmount`
                assembly {
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                ////////////////////////////////////////////////////
                // Note that for Uni V2 flash swaps, the receiver has
                // to be this contract. As such, we have to pre-fund 
                // the next swap
                ////////////////////////////////////////////////////
                tradeId = _preFundTrade(address(this),amountToSwap, data);
                // continue swapping
                tradeId = swapExactIn(amountToSwap, tradeId, address(this), address(this), data);
                // store result in cache
                // if(refAmount >> 128 > tradeId) revert Slippage();
                assembly {
                    if lt(tradeId, shr(128, refAmount)) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }
            amountToSwap = refAmount & UINT128_MASK;
            if(preventSelfPayment) _transferERC20TokensFrom(payer, tokenIn, msg.sender, amountToSwap);
            else _transferERC20Tokens(tokenIn, msg.sender, amountToSwap);
            return;
        } else if (tradeId == 1) {
            assembly {
                tradeId := and(shr(80, calldataload(data.offset)), UINT8_MASK) // swap pool identifier
            }
            // fetch amountOut
            uint256 referenceAmount;
            assembly {
                switch zeroForOne
                case 1 {
                    referenceAmount := amount0
                }
                default {
                    referenceAmount := amount1
                }
            }
            // calculte amountIn (note that tokenIn/out are read inverted at the top)
            referenceAmount = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, referenceAmount, tradeId);
            // either initiate the next swap or pay
            if (data.length > 64) {
                assembly {
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                swapExactOutInternal(referenceAmount, refAmount >> 128, payer, msg.sender, data);
            } else {
                (uint256 payType, uint8 lenderId) = getPayConfig(data);
                // pay the pool
                handlePayPool(
                    tokenOut,
                    preventSelfPayment ? payer : address(this),
                    msg.sender,
                    payType,
                    referenceAmount,
                    lenderId
                );
                // if(refAmount >> 128 < referenceAmount) revert Slippage();
                assembly {
                    if lt(shr(128, refAmount), referenceAmount) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }
            return;
        }
        if (tradeId > 5) {
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through a separate number cache
            uint256 amountToSwap;
            assembly {
                switch zeroForOne
                case 1 {
                    amountToSwap := amount1
                }
                default {
                    amountToSwap := amount0
                }
            }
            if (data.length > 64) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                assembly {
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                uint256 dexId = _preFundTrade(address(this), amountToSwap, data);
                amountToSwap = swapExactIn(amountToSwap, dexId, address(this), address(this), data);
                // supply directly
                tokenOut = getLastToken(data);
            }
            // if(amountToSwap < refAmount >> 128) revert Slippage();
            assembly {
                if lt(amountToSwap, shr(128, refAmount)) {
                    mstore(0, SLIPPAGE)
                    revert (0, 0x4)
                }
            }
            // slice out the end flag

            (uint256 payType, uint8 lenderId) = getPayConfig(data);

            // cache amount
            // 6 is mint / deposit
            if (tradeId == 6) {
                // deposit funds for id == 6
                _deposit(tokenOut, payer, amountToSwap, lenderId);
            } else {
                // repay - tradeId is irMode plus 6
                tradeId -= 6;
                _repay(tokenOut, payer, amountToSwap, tradeId, lenderId);
            }

            // pay the pool
            handlePayPool(
                tokenIn,
                payer,
                msg.sender,
                payType,
                refAmount & UINT128_MASK,
                lenderId
            );
        } else {
            // fetch amountOut
            amount1 = zeroForOne ? amount0 : amount1;
            // assign payType to amount0
            uint8 lenderId;
            (amount0, lenderId) = getPayConfig(data);

            // 3 is deposit
            if (tradeId == 3) {
                _deposit(tokenIn, payer, amount1, lenderId);
            } else {
                // 4, 5 are repay, subtracting 3 yields the interest rate mode
                tradeId -= 3;
                _repay(tokenIn, payer, amount1, tradeId, lenderId);
            }
            assembly {
                tradeId := and(shr(80, calldataload(data.offset)), UINT8_MASK) // swap pool identifier
            }
            // calculate amountIn (note that tokenIn/out are read inverted at the top)
            amount1 = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, amount1, tradeId);
            // constinue swapping if more data is provided
            if (data.length > 64) {
                assembly {
                    data.offset := add(data.offset, 42)
                    data.length := sub(data.length, 42)
                }
                swapExactOutInternal(amount1, refAmount >> 128, payer, msg.sender, data);
            } else {
                // pay the pool
                handlePayPool(
                    tokenOut,
                    payer,
                    msg.sender,
                    amount0,
                    amount1,
                    lenderId
                );
                // if(refAmount >> 128 < amount1) revert Slippage();
                assembly {
                    if lt(shr(128, refAmount), amount1) {
                        mstore(0, SLIPPAGE)
                        revert (0, 0x4)
                    }
                }
            }
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
     * @param receiver address
     * @param path path calldata
     */
    function flashSwapExactOutInternal(
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
                receiver,
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
                switch lt(path.length, 66)
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
                msg.sender,
                reciever,
                path
            );
        }
        // iZi
        else if (poolId == 49) {
            address reciever;
            assembly {
                switch lt(path.length, 66)
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
                msg.sender,
                reciever,
                path
            );
        }
        // uniswapV2 types
        else if (poolId < 150) {
            swapUniV2ExactInComplete(
                amountIn,
                amountOutMinimum, // we need to forward the amountMin
                msg.sender,
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
                _borrow(token, payer, value, paymentType, lenderId);
                _transferERC20Tokens(token, receiver, value);
            } else {
                _preWithdraw(token, payer, value, lenderId);
                // ids 3-7 are reserved
                _withdraw(token, receiver, value, lenderId);
            } 
        } else {
            // otherwise, just transfer it from cached address
            if (payer == address(this)) {
                // pay with tokens already in the contract (for the exact input multihop case)
                _transferERC20Tokens(token, receiver, value);
            } else {
                // pull payment
                _transferERC20TokensFrom(token, payer, receiver, value);
            }
        }
    }
}
