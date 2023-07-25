// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import {IERC20} from "../../../interfaces/IERC20.sol";
import {IComet} from "../../interfaces/IComet.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";
import {CallbackValidation} from "../../dex-tools/uniswap/libraries/CallbackValidation.sol";
import "../base/InternalSwapperComet.sol";

// solhint-disable max-line-length

/**
 * @title MarginTrader contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract CometUniV3Callback is InternalSwapperComet {
    using Path for bytes;
    using SafeCast for uint256;

    constructor(address uniFactory) InternalSwapperComet(uniFactory) {}

    // callback for dealing with margin trades
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory _data
    ) external {
        MarginCallbackData memory data = abi.decode(_data, (MarginCallbackData));
        // fetch trade type and cast to uint256 as Sol always checks equality in this type
        uint256 tradeType = data.tradeType;
        // address user = data.user;
        // fetch pool data
        (address tokenIn, address tokenOut, uint24 fee, bool hasMore) = data.path.decodeFirstPoolAndValidateLength();
        {
            require(msg.sender == address(_toPool(tokenIn, fee, tokenOut)), "Invalid Caller");
        }

        // EXACT IN BASE SWAP
        if (tradeType == 99) {
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            pay(tokenIn, address(this), amountToPay);
        } else {
            // get comet market
            IComet comet = IComet(cos().comet[data.cometId]);

            // COLLATERAL SWAPS
            if (tradeType == 4) {
                if (data.exactIn) {
                    (uint256 amountToWithdraw, uint256 amountToSwap) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    if (hasMore) {
                        // we need to swap to the token that we want to supply
                        // the router returns the amount that we can finally supply to the protocol
                        data.path = data.path.skipToken();
                        amountToSwap = exactInputToSelf(amountToSwap, data.path);

                        // supply directly
                        tokenOut = data.path.getLastToken();
                    }
                    // cache amount
                    cs().amount = amountToSwap;

                    // aavePool.supply(tokenOut, amountToSwap, data.user, 0);
                    comet.supplyTo(data.user, tokenOut, amountToSwap);

                    // withraw and send funds to the pool
                    comet.withdrawFrom(data.user, msg.sender, tokenIn, amountToWithdraw);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));
                    // we supply the amount received directly - together with user provided amount
                    comet.supplyTo(data.user, tokenIn, amountToSupply);
                    // we then swap exact out where the first amount is
                    // borrowed and paid from the money market
                    // the received amount is paid back to the original pool
                    if (hasMore) {
                        data.path = data.path.skipToken();
                        (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();

                        data.tradeType = 13;
                        bool zeroForOne = tokenIn < tokenOut;

                        _toPool(tokenIn, fee, tokenOut).swap(
                            msg.sender,
                            zeroForOne,
                            -amountInLastPool.toInt256(),
                            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                            abi.encode(data)
                        );
                    } else {
                        // cache amount
                        cs().amount = amountInLastPool;

                        comet.withdrawFrom(data.user, msg.sender, tokenOut, amountInLastPool);
                    }
                }
            }
            // OPEN MARGIN
            else if (tradeType == 8) {
                if (data.exactIn) {
                    // multi swap exact in
                    (uint256 amountToBorrow, uint256 amountToSwap) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    if (hasMore) {
                        // we need to swap to the token that we want to supply
                        // the router returns the amount that we can finally supply to the protocol
                        data.path = data.path.skipToken();
                        amountToSwap = exactInputToSelf(amountToSwap, data.path);
                        tokenOut = data.path.getLastToken();
                    }

                    // cache amount
                    cs().amount = amountToSwap;

                    // supply the provided amounts
                    comet.supplyTo(data.user, tokenOut, amountToSwap);

                    // borrow funds (amountIn) from pool
                    comet.withdrawFrom(data.user, msg.sender, tokenIn, amountToBorrow);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    // we supply the amount received directly - together with user provided amount
                    comet.supplyTo(data.user, tokenIn, amountToSupply);
                    if (hasMore) {
                        // we then swap exact out where the first amount is
                        // borrowed and paid from the money market
                        // the received amount is paid back to the original pool
                        data.path = data.path.skipToken();
                        (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();
                        data.tradeType = 13;
                        bool zeroForOne = tokenIn < tokenOut;

                        _toPool(tokenIn, fee, tokenOut).swap(
                            msg.sender,
                            zeroForOne,
                            -amountInLastPool.toInt256(),
                            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                            abi.encode(data)
                        );
                    } else {
                        // cache amount
                        cs().amount = amountInLastPool;
                        comet.withdrawFrom(data.user, msg.sender, tokenOut, amountInLastPool);
                    }
                }
            }
            // EXACT OUT - BORROW (= WITHDRAW)
            else if (tradeType == 13) {
                // multi swap exact out
                uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
                // either initiate the next swap or pay
                if (hasMore) {
                    data.path = data.path.skipToken();
                    (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();

                    bool zeroForOne = tokenIn < tokenOut;

                    _toPool(tokenIn, fee, tokenOut).swap(
                        msg.sender,
                        zeroForOne,
                        -amountToPay.toInt256(),
                        zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                        abi.encode(data)
                    );
                } else {
                    tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                    comet.withdrawFrom(data.user, msg.sender, tokenIn, amountToPay);
                    // cache amount
                    cs().amount = amountToPay;
                }
            }
            // TRIM
            else if (tradeType == 10) {
                if (data.exactIn) {
                    // trim position exact in
                    (uint256 amountToWithdraw, uint256 amountToSwap) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));
                    if (hasMore) {
                        // we need to swap to the token that we want to repay
                        // the router returns the amount that we can use to repay
                        data.path = data.path.skipToken();
                        amountToSwap = exactInputToSelf(amountToSwap, data.path);

                        tokenOut = data.path.getLastToken();
                    }
                    // cache amount
                    cs().amount = amountToSwap;
                    // lending protocol underlyings are approved by default
                    comet.supplyTo(data.user, tokenOut, amountToSwap);

                    // withraw and send funds to the pool
                    comet.withdrawFrom(data.user, msg.sender, tokenIn, amountToWithdraw);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToRepay) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    // repay
                    comet.supplyTo(data.user, tokenIn, amountToRepay);

                    if (hasMore) {
                        // we then swap exact out where the first amount is
                        // withdrawn from the lending protocol pool and paid back to the pool
                        data.path = data.path.skipToken();
                        (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();
                        data.tradeType = 13;
                        bool zeroForOne = tokenIn < tokenOut;

                        _toPool(tokenIn, fee, tokenOut).swap(
                            msg.sender,
                            zeroForOne,
                            -amountInLastPool.toInt256(),
                            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                            abi.encode(data)
                        );
                    } else {
                        // cache amount
                        cs().amount = amountInLastPool;
                        // withraw and send funds to the pool
                        comet.withdrawFrom(data.user, msg.sender, tokenOut, amountInLastPool);
                    }
                }
            }
            // EXACT OUT - PAID BY USER
            else if (tradeType == 12) {
                // multi swap exact out
                uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
                // either initiate the next swap or pay
                if (data.path.hasMultiplePools()) {
                    data.path = data.path.skipToken();
                    (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();
                    bool zeroForOne = tokenIn < tokenOut;
                    // we do not require the condition for the exact output away, that is already done elsewhere
                    _toPool(tokenIn, fee, tokenOut).swap(
                        msg.sender,
                        zeroForOne,
                        -amountToPay.toInt256(),
                        zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                        abi.encode(data)
                    );
                } else {
                    tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                    pay(tokenIn, data.user, amountToPay);
                    // cache amount
                    cs().amount = amountToPay;
                }
            }
        }
    }

    /// @param token The token to pay
    /// @param payer The entity that must pay
    /// @param value The amount to pay
    function pay(
        address token,
        address payer,
        uint256 value
    ) internal {
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            IERC20(token).transfer(msg.sender, value);
        } else {
            // pull payment
            IERC20(token).transferFrom(payer, msg.sender, value);
        }
    }
}
