// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";
import {TransferHelper} from "../../dex-tools/uniswap/libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import "../base/InternalSwapper.sol";

// solhint-disable max-line-length

/**
 * @title MarginTrader contract
 * @notice Allows users to build large margin positions with one contract interaction
 * @author Achthar
 */
contract UniswapV3SwapCallbackModule is InternalSwapper, TokenTransfer {
    using Path for bytes;
    using SafeCast for uint256;

    IPool private immutable _aavePool;

    constructor(address uniFactory, address aavePool) InternalSwapper(uniFactory) {
        _aavePool = IPool(aavePool);
    }

    // callback for dealing with margin trades
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory _data
    ) external {
        MarginCallbackData memory data = abi.decode(_data, (MarginCallbackData));
        // fetch trade type and cast to uint256 as Sol always checks equality in this type
        uint256 tradeType = data.tradeType;

        // fetch pool data
        (address tokenIn, address tokenOut, uint24 fee, bool hasMore) = data.path.decodeFirstPoolAndValidateLength();
        {
            require(msg.sender == address(_toPool(tokenIn, fee, tokenOut)), "Invalid Caller");
        }

        // EXACT IN BASE SWAP
        if (tradeType == 99) {
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            _transferERC20Tokens(tokenIn, msg.sender, amountToPay);
        } else {
            // get aave pool
            IPool aavePool = _aavePool;
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
                    ncs().amount = amountToSwap;
                    address user = acs().cachedAddress;
                    aavePool.supply(tokenOut, amountToSwap, user, 0);

                    // withraw and send funds to the pool
                    _transferERC20TokensFrom(aas().aTokens[tokenIn], user, address(this), amountToWithdraw);
                    aavePool.withdraw(tokenIn, amountToWithdraw, msg.sender);
                    acs().cachedAddress = address(0);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));
                    // we supply the amount received directly - together with user provided amount
                    aavePool.supply(tokenIn, amountToSupply, acs().cachedAddress, 0);
                    // we then swap exact out where the first amount is
                    // borrowed and paid from the money market
                    // the received amount is paid back to the original pool
                    if (hasMore) {
                        data.path = data.path.skipToken();
                        (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();

                        data.tradeType = 14;
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
                        ncs().amount = amountInLastPool;
                        _transferERC20TokensFrom(aas().aTokens[tokenOut], acs().cachedAddress, address(this), amountInLastPool);
                        aavePool.withdraw(tokenOut, amountInLastPool, msg.sender);
                        acs().cachedAddress = address(0);
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
                    ncs().amount = amountToSwap;
                    address user = acs().cachedAddress;
                    // supply the provided amounts
                    aavePool.supply(tokenOut, amountToSwap, user, 0);

                    // borrow funds (amountIn) from pool
                    aavePool.borrow(tokenIn, amountToBorrow, data.interestRateMode, 0, user);
                    _transferERC20Tokens(tokenIn, msg.sender, amountToBorrow);
                    acs().cachedAddress = address(0);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    // we supply the amount received directly - together with user provided amount
                    aavePool.supply(tokenIn, amountToSupply, acs().cachedAddress, 0);

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
                        ncs().amount = amountInLastPool;
                        aavePool.borrow(tokenOut, amountInLastPool, data.interestRateMode, 0, acs().cachedAddress);
                        _transferERC20Tokens(tokenOut, msg.sender, amountInLastPool);
                        acs().cachedAddress = address(0);
                    }
                }
            }
            // DEBT SWAP
            else if (tradeType == 2) {
                if (data.exactIn) {
                    (uint256 amountToBorrow, uint256 amountToSwap) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));
                    if (hasMore) {
                        // we need to swap to the token that we want to repay
                        // the router returns the amount that we can finally repay to the protocol
                        data.path = data.path.skipToken();
                        amountToSwap = exactInputToSelf(amountToSwap, data.path);
                        tokenOut = data.path.getLastToken();
                    }
                    // cache amount
                    ncs().amount = amountToSwap;
                    address user = acs().cachedAddress;
                    aavePool.repay(tokenOut, amountToSwap, data.interestRateMode % 10, user);
                    aavePool.borrow(tokenIn, amountToBorrow, data.interestRateMode / 10, 0, user);
                    _transferERC20Tokens(tokenIn, msg.sender, amountToBorrow);
                    acs().cachedAddress = address(0);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    // we repay the amount received directly
                    aavePool.repay(tokenIn, amountToSupply, data.interestRateMode % 10, acs().cachedAddress);
                    if (hasMore) {
                        // we then swap exact out where the first amount is
                        // borrowed and paid from the money market
                        // the received amount is paid back to the original pool

                        data.path = data.path.skipToken();
                        data.interestRateMode = data.interestRateMode / 10;
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
                        ncs().amount = amountInLastPool;
                        aavePool.borrow(tokenOut, amountInLastPool, data.interestRateMode / 10, 0, acs().cachedAddress);
                        _transferERC20Tokens(tokenOut, msg.sender, amountInLastPool);
                        acs().cachedAddress = address(0);
                    }
                }
            }
            // EXACT OUT - WITHDRAW
            else if (tradeType == 14) {
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
                    // we have to transfer aTokens from the user to this address - these are used to access liquidity
                    _transferERC20TokensFrom(aas().aTokens[tokenIn], acs().cachedAddress, address(this), amountToPay);
                    // cache amount
                    ncs().amount = amountToPay;
                    // withraw and send funds to the pool
                    aavePool.withdraw(tokenIn, amountToPay, msg.sender);
                    acs().cachedAddress = address(0);
                }
            }
            // EXACT OUT - BORROW
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
                    aavePool.borrow(tokenIn, amountToPay, data.interestRateMode, 0, acs().cachedAddress);
                    // cache amount
                    ncs().amount = amountToPay;
                    // send funds to the pool
                    _transferERC20Tokens(tokenIn, msg.sender, amountToPay);
                    acs().cachedAddress = address(0);
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
                    ncs().amount = amountToSwap;
                    address user = acs().cachedAddress;
                    // lending protocol underlyings are approved by default
                    aavePool.repay(tokenOut, amountToSwap, data.interestRateMode, user);

                    // we have to transfer aTokens from the user to this address - these are used to access liquidity
                    _transferERC20TokensFrom(aas().aTokens[tokenIn], user, address(this), amountToWithdraw);
                    // withraw and send funds to the pool
                    aavePool.withdraw(tokenIn, amountToWithdraw, msg.sender);
                    acs().cachedAddress = address(0);
                } else {
                    // multi swap exact out
                    (uint256 amountInLastPool, uint256 amountToRepay) = amount0Delta > 0
                        ? (uint256(amount0Delta), uint256(-amount1Delta))
                        : (uint256(amount1Delta), uint256(-amount0Delta));

                    // repay
                    aavePool.repay(tokenIn, amountToRepay, data.interestRateMode, acs().cachedAddress);

                    if (hasMore) {
                        // we then swap exact out where the first amount is
                        // withdrawn from the lending protocol pool and paid back to the pool
                        data.path = data.path.skipToken();
                        (tokenOut, tokenIn, fee) = data.path.decodeFirstPool();
                        data.tradeType = 14;
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
                        ncs().amount = amountInLastPool;
                        // we have to transfer aTokens from the user to this address - these are used to access liquidity
                        _transferERC20TokensFrom(aas().aTokens[tokenOut], acs().cachedAddress, address(this), amountInLastPool);
                        // withraw and send funds to the pool
                        aavePool.withdraw(tokenOut, amountInLastPool, msg.sender);
                         acs().cachedAddress = address(0);
                    }
                }
            }
            // EXACT OUT - PAID BY USER
            else if (tradeType == 12) {
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
                    pay(tokenIn,  acs().cachedAddress, amountToPay);
                    // cache amount
                    ncs().amount = amountToPay;
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
            _transferERC20Tokens(token, msg.sender, value);
        } else {
            // pull payment
            _transferERC20TokensFrom(token, payer, msg.sender, value);
        }
    }
}
