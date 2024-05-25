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
    // selectors for errors
    bytes4 internal constant SLIPPAGE = 0x7dd37f70;
    // errors
    error Slippage();
    error NoBalance();
    error InvalidDexId();

    bytes32 internal constant DEFAULT_CACHE = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    constructor() BaseSwapper() BaseLending() {}

    /// @dev Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactIn(
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path
    ) external payable {
        _cacheCaller();
        uint256 amountOut = flashSwapExactInInternal(amountIn, path);
        // slippage check
        assembly {
            if lt(amountOut, amountOutMinimum) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
    }

    // Exact Output Swap - The path parameters determine the lending actions
    function flashSwapExactOut(
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path
    ) external payable {
        _cacheCaller();
        flashSwapExactOutInternal(amountOut, address(this), path);
        // slippage check
        assembly {
            let amountIn := sload(CACHE_SLOT)
            if gt(amountIn, amountInMaximum) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(CACHE_SLOT, DEFAULT_CACHE)
        }
    }

    // Exact Input Swap where the entire collateral amount is withdrawn - The path parameters determine the lending actions
    // if the collateral balance is zerp. the tx reverts
    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable {
        _cacheCaller();
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
        uint256 amountOut = flashSwapExactInInternal(amountIn, path);
        assembly {
            if lt(amountOut, amountOutMinimum) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
        }
    }

    // Exact Output Swap where the entire debt balacne is repaid - The path parameters determine the lending actions
    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable {
        _cacheCaller();
        uint256 amountOut;
        {
            address tokenOut;
            uint8 _identifier;
            // we need tokenIn together with lender id for he balance fetch
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := shr(96, firstWord)
                _identifier := shr(56, firstWord)
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

        flashSwapExactOutInternal(amountOut, address(this), path);
        // slippage check
        assembly {
            let amountIn := sload(CACHE_SLOT)
            if gt(amountIn, amountInMaximum) {
                mstore(0, SLIPPAGE)
                revert (0, 0x4)
            }
            // reset cache
            sstore(CACHE_SLOT, DEFAULT_CACHE)
        }
    }

    // fusionx
    function fusionXV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, data);
    }

    // agni
    function agniSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, _data);
    }

    // swapsicle
    function algebraSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, path);
    }

    // butter
    function butterSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external  {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, path);
    }

    // cleo
    function ramsesV2SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external  {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, path);
    }

    // methlab
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata path
    ) external {
        uniswapV3SwapCallbackInternal(amount0Delta, amount1Delta, path);
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
    function uniswapV3SwapCallbackInternal(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) private {
        address tokenIn;
        address tokenOut;
        uint256 tradeId;
        bool payFromCache;
        assembly {
            let firstWord := calldataload(_data.offset)
            
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            tradeId := and(shr(80, firstWord), UINT8_MASK) // poolId
            // second word
            firstWord := calldataload(add(_data.offset, 22))
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
            let pool
            switch tradeId
            // Fusion
            case 0 {
                mstore(p, FUSION_V3_FF_FACTORY)
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
                mstore(p, FUSION_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // agni
            case 1 {
                mstore(p, AGNI_V3_FF_FACTORY)
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
                mstore(p, AGNI_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Algebra / Swapsicle
            case 2 {
                mstore(p, ALGEBRA_V3_FF_DEPLOYER)
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
                mstore(p, keccak256(p, 64))
                p := add(p, 32)
                mstore(p, ALGEBRA_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Butter
            case 3 {
                mstore(p, BUTTER_FF_FACTORY)
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
                mstore(p, BUTTER_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // Cleo
            case 4 {
                mstore(p, CLEO_FF_FACTORY)
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
                mstore(p, CLEO_POOL_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // MethLab
            case 5 {
                mstore(p, METHLAB_FF_FACTORY)
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
                mstore(p, METHLAB_INIT_CODE_HASH)
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }
            // iZi
            default {
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
                pool := and(ADDRESS_MASK, keccak256(s, 85))
            }

            // if the caller is not the calculated pool, we rever
            if iszero(eq(caller(), pool)) {
                revert (0, 0)
            }
            // use tradeId as tradetype
            tradeId := and(shr(88, calldataload(_data.offset)) , UINT8_MASK)
            // 10 (11) means that we are paying from the cache in an exact input (output)
            // scenario
            if eq(tradeId, 10) {
                payFromCache := 1
                tradeId := 0
            }        
            if eq(tradeId, 11) {
                payFromCache := 1
                tradeId := 1
            }
        }
        // EXACT IN BASE SWAP
        if (tradeId == 0) {
            uint256 amountOut;
            // assign the amount to pay to the local stack
            (tradeId, amountOut) = amount0Delta > 0 ? 
                (uint256(amount0Delta), uint256(-amount1Delta)): 
                (uint256(amount1Delta), uint256(-amount0Delta));
            // of additional data is provided, we execute the swap nested
            if (_data.length > 64) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                _data = _data[24:];
                // we have to cache the amountOut in this case
                amountOut = swapExactIn(amountOut, address(this), _data);
                assembly {
                    sstore(CACHE_SLOT, amountOut)
                }
            }
            if(payFromCache) _transferERC20TokensFrom(tokenIn, getCachedAddress(), msg.sender, tradeId);
            else _transferERC20Tokens(tokenIn, msg.sender, tradeId);
            return;
        }
        // EXACT OUT - WITHDRAW, BORROW OR PAY
        else if (tradeId == 1) {
            // fetch amount that has to be paid to the pool
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            // either initiate the next swap or pay
            if (_data.length > 64) {
                _data = _data[24:];
                flashSwapExactOutInternal(amountToPay, msg.sender, _data);
            } else {
                // fetch payment config
                (uint256 payType, uint8 lenderId) = getPayConfig(_data);
                // pay the pool
                handleTransferOut(
                    tokenOut,
                    getCachedAddress(),
                    msg.sender,
                    payType,
                    amountToPay,
                    lenderId
                );
                // cache amount
                assembly {
                    sstore(CACHE_SLOT, amountToPay)
                }
            }
            return;
        }
        // MARGIN TRADING INTERACTIONS
        else {
            // exact in
            if (tradeId > 5) {
                (uint256 amountToRepayToPool, uint256 amountToSwap) = amount0Delta > 0
                    ? (uint256(amount0Delta), uint256(-amount1Delta))
                    : (uint256(amount1Delta), uint256(-amount0Delta)); 
                ////////////////////////////////////////////////////
                // If the path is longer than 2 addresses, uint16, 3 uint8s
                // We try to continue to swap
                ////////////////////////////////////////////////////
                if (_data.length > 46) { 
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    _data = _data[24:];
                    amountToSwap = swapExactIn(amountToSwap, address(this), _data);
                    // re-assign tokenOut
                    tokenOut = getLastToken(_data);
                }
                // slice out the end flag
                // _data = _data[(cache - 1):cache];

                (uint256 payType, uint8 lenderId) = getPayConfig(_data);
                address user = getCachedAddress();
                // 6 is mint / deposit
                if (tradeId == 6) {
                    _deposit(tokenOut, user, amountToSwap, lenderId);
                } else {
                    // tradeId minus 6 yields the interest rate mode
                    tradeId -= 6;
                    _repay(tokenOut, user, amountToSwap, tradeId, lenderId);
                }
                // pay the pool
                handleTransferOut(
                    tokenIn,
                    user,
                    msg.sender,
                    payType,
                    amountToRepayToPool,
                    lenderId
                );
                // cache amount
                assembly {
                    sstore(CACHE_SLOT, amountToSwap)
                }
            } else {
                (uint256 payType, uint8 lenderId) = getPayConfig(_data);
                address user = getCachedAddress();
                // exact out
                (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                    ? (uint256(amount0Delta), uint256(-amount1Delta))
                    : (uint256(amount1Delta), uint256(-amount0Delta));
                // 3 is deposit
                if (tradeId == 3) {
                     _deposit(tokenIn, user, amountToSupply, lenderId);
                } else {
                    // 4, 5 are repay - subtracting 3 yields the interest rate mode
                    tradeId -= 3;
                    _repay(tokenIn, user, amountToSupply, tradeId, lenderId);
                }

                // multihop if required
                if (_data.length > MINIMUM_PATH_LENGTH) {
                    _data = _data[24:];
                    flashSwapExactOutInternal(amountInLastPool, msg.sender, _data);
                } else {
                    // pay the pool
                    handleTransferOut(
                        tokenOut,
                        user,
                        msg.sender,
                        payType,
                        amountInLastPool,
                        lenderId
                    );
                    // cache amount
                    assembly {
                        sstore(CACHE_SLOT, amountInLastPool)
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
        _uniswapV2StyleCallback(amount0, amount1, data);
    }

    // The uniswapV2 style callback for Merchant Moe
    function moeCall(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        _uniswapV2StyleCallback(amount0, amount1, data);
    }

    // The uniswapV2 style callback for Velocimeter, Cleopatra V1 and Stratum
    function hook(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        _uniswapV2StyleCallback(amount0, amount1, data);
    }

    /**
     * Flash swap callback for all UniV2 and Solidly type DEXs
     * @param amount0 amount of token0 received
     * @param amount1 amount of token1 received
     * @param data path calldata
     */
    function _uniswapV2StyleCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) private {
        uint256 tradeId;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        bool payFromCache;
        uint8 identifier;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, firstWord))
            identifier := and(shr(80, firstWord), UINT8_MASK) // swap pool identifier
            tradeId := and(shr(88, firstWord), UINT8_MASK) // interaction identifier
            tokenOut := and(ADDRESS_MASK, shr(96, calldataload(add(data.offset, 22))))
            zeroForOne := lt(tokenIn, tokenOut)
            
            let pair
            switch identifier
            // FusionX
            case 50 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                let salt := keccak256(0xB0C, 0x28)
                mstore(0xB00, FUSION_V2_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CODE_HASH_FUSION_V2)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 51: Merchant Moe
            case 51 {
                // selector for getPair(address,address)
                mstore(0xB00, 0xe6a4390500000000000000000000000000000000000000000000000000000000)
                mstore(add(0xB00, 0x4), tokenIn)
                mstore(add(0xB00, 0x24), tokenOut)

                // call to collateralToken
                pop(staticcall(gas(), MERCHANT_MOE_FACTORY, 0xB00, 0x48, 0xB00, 0x20))

                // load the retrieved protocol share
                pair := and(ADDRESS_MASK, mload(0xB00))
            }
            // Velo Volatile
            case 52 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Velo Stable
            case 53 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Cleo V1 Volatile
            case 54 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, CLEO_V1_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Cleo V1 Stable
            case 55 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, CLEO_V1_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, CLEO_V1_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // Stratum Volatile
            case 56 {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, STRATUM_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            // 57: Stratum Stable
            default {
                switch zeroForOne
                case 0 {
                    mstore(0xB14, tokenIn)
                    mstore(0xB00, tokenOut)
                }
                default {
                    mstore(0xB14, tokenOut)
                    mstore(0xB00, tokenIn)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, STRATUM_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, STRATUM_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }

            // verify that the caller is a v2 type pool
            if iszero(eq(pair, caller())) {
                revert (0, 0)
            }
            // use tradeId as tradetype
            tradeId := and(shr(88, firstWord) , UINT8_MASK)
            // 10 (11) means that we are paying from the cache in an exact input (output)
            // scenario
            if eq(tradeId, 10) {
                payFromCache := 1
                tradeId := 0
            }        
            if eq(tradeId, 11) {
                payFromCache := 1
                tradeId := 1
            }
        }

        // exact in is handled outside a callback
        if (tradeId == 0) {
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through the cache
            uint256 amountToSwap = zeroForOne ? amount1 : amount0;
            if (data.length > MINIMUM_PATH_LENGTH) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                data = data[22:];
                // store the output amount
                tradeId = swapExactIn(amountToSwap, address(this), data);
                assembly {
                    sstore(CACHE_SLOT, tradeId)
                }
            }
            amountToSwap = getV2AmountInDirect(msg.sender, tokenIn, tokenOut, amountToSwap, identifier);
            if(payFromCache) _transferERC20TokensFrom(getCachedAddress(), tokenIn, msg.sender, amountToSwap);
            else _transferERC20Tokens(tokenIn, msg.sender, amountToSwap);
            return;
        } else if (tradeId == 1) {
            // fetch amountOut
            uint256 referenceAmount = zeroForOne ? amount0 : amount1;
            // calculte amountIn (note that tokenIn/out are read inverted at the top)
            referenceAmount = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, referenceAmount, identifier);
            // either initiate the next swap or pay
            if (data.length > MINIMUM_PATH_LENGTH) {
                data = data[22:];
                flashSwapExactOutInternal(referenceAmount, msg.sender, data);
            } else {
                (uint256 payType, uint8 lenderId) = getPayConfig(data);
                // pay the pool
                handleTransferOut(
                    tokenOut,
                    getCachedAddress(),
                    msg.sender,
                    payType,
                    referenceAmount,
                    lenderId
                );
                // cache amount
                assembly {
                    sstore(CACHE_SLOT, referenceAmount)
                }
            }
            return;
        }
        if (tradeId > 5) {
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through a separate number cache
            uint256 amountToSwap = zeroForOne ? amount1 : amount0;
            uint256 amountToBorrow = getV2AmountInDirect(msg.sender, tokenIn, tokenOut, amountToSwap, identifier);
            if (data.length > 43) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                data = data[22:];
                amountToSwap = swapExactIn(amountToSwap, address(this), data);
                // supply directly
                tokenOut = getLastToken(data);
            }
            // slice out the end flag

            (uint256 payType, uint8 lenderId) = getPayConfig(data);
            address user = getCachedAddress();

            // cache amount
            // 6 is mint / deposit
            if (tradeId == 6) {
                // deposit funds for id == 6
                _deposit(tokenOut, user, amountToSwap, lenderId);
            } else {
                // repay - tradeId is irMode plus 6
                tradeId -= 6;
                _repay(tokenOut, user, amountToSwap, tradeId, lenderId);
            }

            // pay the pool
            handleTransferOut(
                tokenIn,
                user,
                msg.sender,
                payType,
                amountToBorrow,
                lenderId
            );
            // cache amount
            assembly {
                sstore(CACHE_SLOT, amountToSwap)
            }
        } else {
            // fetch amountOut
            uint256 referenceAmount = zeroForOne ? amount0 : amount1;
            address user = getCachedAddress();
            (uint256 payType, uint8 lenderId) = getPayConfig(data);

            // 3 is deposit
            if (tradeId == 3) {
                _deposit(tokenIn, user, referenceAmount, lenderId);
            } else {
                // 4, 5 are repay, subtracting 3 yields the interest rate mode
                tradeId -= 3;
                _repay(tokenIn, user, referenceAmount, tradeId, lenderId);
            }
            // calculate amountIn (note that tokenIn/out are read inverted at the top)
            referenceAmount = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, referenceAmount, identifier);
            // constinue swapping if more data is provided
            if (data.length > MINIMUM_PATH_LENGTH) {
                data = data[25:];
                flashSwapExactOutInternal(referenceAmount, msg.sender, data);
            } else {
                // pay the pool
                handleTransferOut(
                    tokenOut,
                    user,
                    msg.sender,
                    payType,
                    referenceAmount,
                    lenderId
                );
                // cache amount
                assembly {
                    sstore(CACHE_SLOT, referenceAmount)
                }
            }
        }
    }

    // iZi callbacks
    
    // zeroForOne = true
    function swapY2XCallback(uint256 x, uint256 y, bytes calldata path) external {
        uniswapV3SwapCallbackInternal(
            -int256(x),
            int256(y),
            path
        );
    }

    // zeroForOne = false
    function swapX2YCallback(uint256 x, uint256 y, bytes calldata path) external {
        uniswapV3SwapCallbackInternal(
            int256(x),
            -int256(y),
            path
        );
    }

    /**
     * (flash, whenever possible)-swaps exact output
     * Funds are sent to receiver address
     * Path is assumed to start from output token
     * The input amount is cached and not directly returned by this function
     * @param amountOut buy amount
     * @param receiver address
     * @param path path calldata
     */
    function flashSwapExactOutInternal(uint256 amountOut, address receiver, bytes calldata path) internal {
        // fetch the pool identifier from the path
        uint256 identifier;
        assembly {
            identifier := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 style
        if (identifier < 50) {
            _swapUniswapV3PoolExactOut(
                receiver,
                -int256(amountOut),
                path
            );
        }
        // uniswapV2 style
        else if (identifier < 100) {
            _swapV2StyleExactOut(amountOut, receiver, path);
        }
        // iZi
        else if (identifier == 100) {
            _swapIZIPoolExactOut(
                receiver,
                uint128(amountOut),
                path
            );
        // special case: Moe LB, no flash swaps, recursive nesting is applied
        } else if (identifier == 103) {
            uint24 bin;
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(path.offset)
                tokenOut := and(ADDRESS_MASK, shr(96, firstWord))
                bin := and(shr(80, firstWord), UINT24_MASK)
                tokenIn := and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 22))))
            }
            ////////////////////////////////////////////////////
            // We calculate the required amount for the next swap
            ////////////////////////////////////////////////////
            (uint256 amountIn, address pair, bool swapForY) = getLBAmountIn(tokenIn, tokenOut, amountOut, uint16(bin));

            ////////////////////////////////////////////////////
            // If the path includes more pairs, we nest another exact out swap
            // The funds of this exact out swap are sent to the LB pair
            // This is done by re-calling this same function after skimming the
            // data parameter by the leading token config 
            ////////////////////////////////////////////////////
            if(path.length > MINIMUM_PATH_LENGTH) {
                // remove the last token from the path
                path = path[25:];
                flashSwapExactOutInternal(amountIn, pair, path);
            } 
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                (uint256 payType, uint8 lenderId) = getPayConfig(path);
                // pay the pool
                handleTransferOut(tokenIn, getCachedAddress(), pair, payType, amountIn, lenderId);
                // only cache the amount if this is the last pool
                gcs().cache = bytes32(amountIn);
            }
            ////////////////////////////////////////////////////
            // The swap is executed at the end and sends 
            // the funds to the receiver addresss
            ////////////////////////////////////////////////////
            swapLBexactOut(pair, swapForY, amountOut, receiver);
        } else
            revert invalidDexId();
    }

    // Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactInInternal(
        uint256 amountIn,
        bytes calldata path
    ) internal returns (uint256 amountOut) {
        // fetch the pool identifier from the path
        uint256 identifier;
        assembly {
            identifier := and(shr(80, calldataload(path.offset)), UINT8_MASK)
        }
        // uniswapV3 types
        if (identifier < 50) {
            _swapUniswapV3PoolExactIn(
                address(this),
                int256(amountIn),
                path
            );
        }
        // uniswapV2 types
        else if (identifier < 100) {
            swapUniV2ExactInComplete(
                amountIn,
                address(this),
                true,
                path
            );
        }
        // iZi
        else if (identifier == 100) {
            _swapIZIPoolExactIn(
                address(this),
                uint128(amountIn),
                path
            );
        } else revert InvalidDexId();

        // get the output and reset the cache
        assembly {
            amountOut := sload(CACHE_SLOT)
            sstore(CACHE_SLOT, DEFAULT_CACHE)
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
    function handleTransferOut(
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
            if (payer == address(0)) {
                // pay with tokens already in the contract (for the exact input multihop case)
                _transferERC20Tokens(token, receiver, value);
            } else {
                // pull payment
                _transferERC20TokensFrom(token, payer, receiver, value);
            }
        }
    }
}
