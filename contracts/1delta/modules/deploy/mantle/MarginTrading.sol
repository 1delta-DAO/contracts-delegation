// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.25;

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
    error Slippage();
    error NoBalance();
    error InvalidDexId();

    constructor() BaseSwapper() BaseLending() {}

    /// @dev Exact Input Flash Swap - The path parameters determine the lending actions
    function flashSwapExactIn(
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path
    ) external payable returns (uint256 amountOut) {
        _cacheCaller();
        amountOut = flashSwapExactInInternal(amountIn, path);
        if (amountOutMinimum > amountOut) revert Slippage();
    }

    // Exact Output Swap - The path parameters determine the lending actions
    function flashSwapExactOut(
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path
    ) external payable returns (uint256 amountIn) {
        _cacheCaller();
        flashSwapExactOutInternal(amountOut, address(this), path);
        amountIn = uint256(gcs().cache);
        gcs().cache = 0x0;
        if (amountInMaximum < amountIn) revert Slippage();
    }

    // Exact Input Swap where the entire collateral amount is withdrawn - The path parameters determine the lending actions
    // if the collateral balance is zerp. the tx reverts
    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable returns (uint256 amountOut) {
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
        amountOut = flashSwapExactInInternal(amountIn, path);
        if (amountOutMinimum > amountOut) revert Slippage();
    }

    // Exact Output Swap where the entire debt balacne is repaid - The path parameters determine the lending actions
    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable returns (uint256 amountIn) {
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
        amountIn = uint256(gcs().cache);
        gcs().cache = 0x0;
        if (amountInMaximum < amountIn) revert Slippage();
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
        uint24 fee;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(_data.offset)
            tokenIn := shr(96, firstWord)
            fee := and(shr(72, firstWord), UINT24_MASK) // uniswapV3 type fee
            tradeId := and(shr(64, firstWord), UINT8_MASK) // poolId
            tokenOut := shr(96, calldataload(add(_data.offset, 25)))
        }
        
        // validate callback
        validateUniV3TypePool(tokenIn, tokenOut, fee, tradeId);

        assembly {
            // get the trade type from the path
            tradeId := and(shr(56, calldataload(_data.offset)) , UINT8_MASK)
        }

        // EXACT IN BASE SWAP
        if (tradeId == 0) {
            uint256 amountOut;
            // assign the amount to pay to the local stack
            (tradeId, amountOut) = amount0Delta > 0 ? 
                (uint256(amount0Delta), uint256(-amount1Delta)): 
                (uint256(amount1Delta), uint256(-amount0Delta));
            // of additional data is provided, we execute the swap nested
            if (_data.length > MINIMUM_PATH_LENGTH) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                _data = _data[25:];
                // we have to cache the amountOut in this case
                gcs().cache = bytes32(swapExactIn(amountOut, _data));
            }
            _transferERC20Tokens(tokenIn, msg.sender, tradeId);
            return;
        }
        // EXACT OUT - WITHDRAW, BORROW OR PAY
        else if (tradeId == 1) {
            // fetch amount that has to be paid to the pool
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            // either initiate the next swap or pay
            if (_data.length > MINIMUM_PATH_LENGTH) {
                _data = _data[25:];
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
                gcs().cache = bytes32(amountToPay);
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
                uint256 cache = _data.length;
                if (cache > MINIMUM_PATH_LENGTH) {
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    _data = _data[25:];
                    amountToSwap = swapExactIn(amountToSwap, _data);
                    // re-assign tokenOut
                    tokenOut = getLastToken(_data);
                    cache = _data.length;
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
                gcs().cache = bytes32(amountToSwap);
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
                    _data = _data[25:];
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
                    gcs().cache = bytes32(amountInLastPool);
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
        uint8 identifier;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
            tokenIn := shr(96, firstWord)
            identifier := shr(64, firstWord) // swap pool identifier
            tradeId := and(shr(56, firstWord), UINT8_MASK) // interaction identifier
            tokenOut := shr(96, calldataload(add(data.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }
        // verify that the caller is a v2 type pool
        validateV2PairAddress(tokenIn, tokenOut, identifier);

        // exact in is handled outside a callback
        if (tradeId == 0) {
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through the cache
            uint256 amountToSwap = zeroForOne ? amount1 : amount0;
            if (data.length > MINIMUM_PATH_LENGTH) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                data = data[25:];
                // store the output amount
                gcs().cache = bytes32(swapExactIn(amountToSwap, data));
            }
            _transferERC20Tokens(tokenIn, msg.sender, getV2AmountInDirect(msg.sender, tokenIn, tokenOut, amountToSwap, identifier));
            return;
        } else if (tradeId == 1) {
            // fetch amountOut
            uint256 referenceAmount = zeroForOne ? amount0 : amount1;
            // calculte amountIn (note that tokenIn/out are read inverted at the top)
            referenceAmount = getV2AmountInDirect(msg.sender, tokenOut, tokenIn, referenceAmount, identifier);
            uint256 cache = data.length;
            // either initiate the next swap or pay
            if (cache > MINIMUM_PATH_LENGTH) {
                data = data[25:];
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
                gcs().cache = bytes32(referenceAmount);
            }
            return;
        }
        if (tradeId > 5) {
            uint256 cache = data.length;
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through a separate number cache
            uint256 amountToSwap = zeroForOne ? amount1 : amount0;
            uint256 amountToBorrow = getV2AmountInDirect(msg.sender, tokenIn, tokenOut, amountToSwap, identifier);
            if (cache > MINIMUM_PATH_LENGTH) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                data = data[25:];
                amountToSwap = swapExactIn(amountToSwap, data);
                // supply directly
                tokenOut = getLastToken(data);
                cache = data.length;
            }
            // slice out the end flag
            // data = data[(cache - 1):cache];

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
            gcs().cache = bytes32(amountToSwap);
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
            uint256 cache = data.length;
            // constinue swapping if more data is provided
            if (cache > MINIMUM_PATH_LENGTH) {
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
                gcs().cache = bytes32(referenceAmount);
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
     * @param data path calldata
     */
    function flashSwapExactOutInternal(uint256 amountOut, address receiver, bytes calldata data) internal {
        // fetch the pool identifier from the path
        uint256 identifier;
        assembly {
            identifier := and(shr(64, calldataload(data.offset)), UINT8_MASK)
        }

        // uniswapV3 style
        if (identifier < 50) {
            _swapUniswapV3PoolExactOut(
                receiver,
                -int256(amountOut),
                data
            );
        }
        // uniswapV2 style
        else if (identifier < 100) {
            _swapV2StyleExactOut(amountOut, receiver, data);
        }
        // iZi
        else if (identifier == 100) {
            _swapIZIPoolExactOut(
                receiver,
                uint128(amountOut),
                data
            );
        // special case: Moe LB, no flash swaps, recursive nesting is applied
        } else if (identifier == 103) {
            uint24 bin;
            address tokenIn;
            address tokenOut;
            assembly {
                let firstWord := calldataload(data.offset)
                tokenOut := shr(96, firstWord)
                bin := and(shr(72, firstWord), UINT24_MASK)
                tokenIn := shr(96, calldataload(add(data.offset, 25)))
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
            if(data.length > MINIMUM_PATH_LENGTH) {
                // remove the last token from the path
                data = data[25:];
                flashSwapExactOutInternal(amountIn, pair, data);
            } 
            ////////////////////////////////////////////////////
            // Otherwise, we pay the funds to the pair
            // according to the parametrization
            // at the end of the path
            ////////////////////////////////////////////////////
            else {
                (uint256 payType, uint8 lenderId) = getPayConfig(data);
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
            identifier := and(shr(64, calldataload(path.offset)), UINT8_MASK)
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
            swapUniV2ExactInComplete(amountIn, true, path);
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
        amountOut = uint256(gcs().cache);
        gcs().cache = 0x0;
    }

    function getPayConfig(bytes calldata data) internal pure returns(uint256 payType, uint8 lenderId){
        // assembly {
        //     let lastWord := calldataload(
        //         sub(
        //             add(data.length, data.offset),
        //             32
        //         )
        //     )
        //     payType := and(shr(lastWord, 8), UINT8_MASK)
        //     lenderId := and(lastWord, UINT8_MASK)
        // }
        uint256 len = data.length;
        payType = uint8(bytes1(data[(len - 2):(len - 1)]));
        lenderId = uint8(bytes1(data[(len - 1):(len)]));
    }

    function getLender(bytes calldata data) internal pure returns(uint8 lenderId){
        assembly {
            lenderId := and(
                calldataload(
                sub(
                    add(data.length, data.offset),
                    32
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
