// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {WithStorage} from "../../../storage/BrokerStorage.sol";
import {BaseSwapper, IUniswapV2Pair} from "./BaseSwapper.sol";
import {ILendingPool} from "./ILendingPool.sol";
import {IERC20Balance} from "../../../interfaces/IERC20Balance.sol";

// solhint-disable max-line-length

/**
 * @title Contract Module for general Margin Trading on an Aave-style Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract MarginTrading is WithStorage, BaseSwapper {
    // errors
    error Slippage();
    error NoBalance();

    // values to reset cache with
    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;
    address private constant DEFAULT_ADDRESS_CACHED = address(0);

    // constant pool
    ILendingPool internal constant _lendingPool = ILendingPool(0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3);

    constructor() BaseSwapper() {}

    // Exact Input Swap - The path parameters determine the lending actions
    function flashSwapExactIn(
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata path
    ) external payable returns (uint256 amountOut) {
        acs().cachedAddress = msg.sender;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        uint8 identifier;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenIn := shr(96, firstWord)
            identifier := shr(64, firstWord)
            tokenOut := shr(96, calldataload(add(path.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }

        // uniswapV3 types
        if (identifier < 50) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swap(
                address(this),
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                path
            );
        }
        // uniswapV2 types
        else if (identifier < 100) {
            ncs().amount = amountIn;
            tokenOut = pairAddress(tokenIn, tokenOut, identifier);
            (uint256 amount0Out, uint256 amount1Out) = zeroForOne
                ? (uint256(0), getAmountOutUniV2(tokenOut, tokenIn, zeroForOne, amountIn, identifier))
                : (getAmountOutUniV2(tokenOut, tokenIn, zeroForOne, amountIn, identifier), uint256(0));
            IUniswapV2Pair(tokenOut).swap(amount0Out, amount1Out, address(this), path);
        }
        // iZi
        else if (identifier == 100) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            if (zeroForOne)
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2Y(
                    address(this),
                    uint128(amountIn),
                    -799999,
                    path
                );
            else
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2X(
                    address(this),
                    uint128(amountIn),
                    799999,
                    path
                );
        }
        amountOut = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
        if (amountOutMinimum > amountOut) revert Slippage();
    }

    // Exact Output Swap - The path parameters determine the lending actions
    function flashSwapExactOut(
        uint256 amountOut,
        uint256 amountInMaximum,
        bytes calldata path
    ) external payable returns (uint256 amountIn) {
        acs().cachedAddress = msg.sender;
        flashSwapExactOutInternal(amountOut, address(this), path);
        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
        if (amountInMaximum < amountIn) revert Slippage();
    }

    // Exact Input Swap where the entire collateral amount is withdrawn - The path parameters determine the lending actions
    // if the collateral balance is zerp. the tx reverts
    function flashSwapAllIn(uint256 amountOutMinimum, bytes calldata path) external payable returns (uint256 amountOut) {
        acs().cachedAddress = msg.sender;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        uint8 identifier;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenIn := shr(96, firstWord)
            identifier := shr(64, firstWord)
            tokenOut := shr(96, calldataload(add(path.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }
        // fetch collateral balance
        uint256 amountIn = IERC20Balance(aas().aTokens[tokenIn]).balanceOf(msg.sender);
        if (amountIn == 0) revert NoBalance();

        // uniswapV3 style
        if (identifier < 50) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swap(
                address(this),
                zeroForOne,
                int256(amountIn),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                path
            );
        }
        // unsiwapV2 types
        else if (identifier < 100) {
            ncs().amount = amountIn;
            tokenOut = pairAddress(tokenIn, tokenOut, identifier);
            (uint256 amount0Out, uint256 amount1Out) = zeroForOne
                ? (uint256(0), getAmountOutUniV2(tokenOut, tokenIn, zeroForOne, amountIn, identifier))
                : (getAmountOutUniV2(tokenOut, tokenIn, zeroForOne, amountIn, identifier), uint256(0));
            IUniswapV2Pair(tokenOut).swap(amount0Out, amount1Out, address(this), path);
        }
        // iZi
        else if (identifier == 100) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            if (zeroForOne)
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2Y(
                    address(this),
                    uint128(amountIn),
                    -799999,
                    path
                );
            else
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2X(
                    address(this),
                    uint128(amountIn),
                    799999,
                    path
                );
        }
        amountOut = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
        if (amountOutMinimum > amountOut) revert Slippage();
    }

    // Exact Output Swap where the entire debt balacne is repaid - The path parameters determine the lending actions
    function flashSwapAllOut(uint256 amountInMaximum, bytes calldata path) external payable returns (uint256 amountIn) {
        acs().cachedAddress = msg.sender;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        uint8 identifier;
        assembly {
            let firstWord := calldataload(path.offset)
            tokenOut := shr(96, firstWord)
            identifier := shr(56, firstWord)
            tokenIn := shr(96, calldataload(add(path.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }

        // determine output amount as respective debt balance
        uint256 amountOut;
        if (identifier == 5) amountOut = IERC20Balance(aas().vTokens[tokenOut]).balanceOf(msg.sender);
        else amountOut = IERC20Balance(aas().sTokens[tokenOut]).balanceOf(msg.sender);
        if (amountOut == 0) revert NoBalance();

        // fetch poolId - store it in identifier
        assembly {
            identifier := shr(64, calldataload(path.offset))
        }

        // uniswapV3 types
        if (identifier < 50) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swap(
                address(this),
                zeroForOne,
                -int256(amountOut),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                path
            );
        }
        // uniswapV2 types
        else if (identifier < 100) {
            tokenIn = pairAddress(tokenIn, tokenOut, identifier);
            (uint256 amount0Out, uint256 amount1Out) = zeroForOne ? (uint256(0), amountOut) : (amountOut, uint256(0));
            IUniswapV2Pair(tokenIn).swap(amount0Out, amount1Out, address(this), path);
        }
        // iZi
        else if (identifier == 100) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(path.offset)), 0xffffff)
            }
            if (zeroForOne)
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2YDesireY(
                    address(this),
                    uint128(amountOut),
                    -800001,
                    path
                );
            else
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2XDesireX(
                    address(this),
                    uint128(amountOut),
                    800001,
                    path
                );
        }
        amountIn = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        acs().cachedAddress = DEFAULT_ADDRESS_CACHED;
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

    // PATH IDENTIFICATION

    // [between pools if more than one]
    // 0: exact input swap
    // 1: exact output swap - flavored by the id given at the end of the path

    // [end flag]
    // 1: borrow stable
    // 2: borrow variable
    // 3: withdraw
    // 4: pay from cached address (spot)

    // [start flag (>1)]
    // 6: deposit exact in
    // 7: repay exact in stable
    // 8: repay exact in variable

    // 3: deposit exact out
    // 4: repay exact out stable
    // 5: repay exact out variable

    // The uniswapV3 style callback
    function uniswapV3SwapCallbackInternal(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) private {
        uint8 identifier;
        address tokenIn;
        uint24 fee;
        address tokenOut;
        uint256 tradeId;
        assembly {
            let firstWord := calldataload(_data.offset)
            tokenIn := shr(96, firstWord)
            fee := and(shr(72, firstWord), 0xffffff) // uniswapV3 type fee
            identifier := shr(64, firstWord) // poolId
            tokenOut := shr(96, calldataload(add(_data.offset, 25)))
        }
        {
            require(msg.sender == address(getUniswapV3Pool(tokenIn, tokenOut, fee, identifier)));
        }
        assembly {
            identifier := shr(56, calldataload(_data.offset)) // identifier for tradeType
        }
        tradeId = identifier;
        // EXACT IN BASE SWAP
        if (tradeId == 0) {
            tradeId = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            _transferERC20Tokens(tokenIn, msg.sender, tradeId);
        }
        // EXACT OUT - WITHDRAW or BORROW
        else if (tradeId == 1) {
            // fetch amount that has to be paid to the pool
            uint256 amountToPay = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
            // either initiate the next swap or pay
            if (_data.length > 46) {
                _data = _data[25:];
                flashSwapExactOutInternal(amountToPay, msg.sender, _data);
            } else {
                // re-assign identifier
                uint256 cache = _data.length;
                _data = _data[(cache - 1):cache];
                // assign end flag to cache
                cache = uint8(bytes1(_data));

                if (cache < 3) {
                    // borrow and repay pool - tradeId matches interest rate mode (reverts within Aave when 0 is selected)
                    _lendingPool.borrow(tokenOut, amountToPay, cache, 0, acs().cachedAddress);
                    _transferERC20Tokens(tokenOut, msg.sender, amountToPay);
                } else if (cache < 8) {
                    // ids 3-7 are reserved
                    // withraw and send funds to the pool
                    _transferERC20TokensFrom(aas().aTokens[tokenOut], acs().cachedAddress, address(this), amountToPay);
                    _lendingPool.withdraw(tokenOut, amountToPay, msg.sender);
                } else {
                    // otherwise, just transfer it from cached address
                    pay(tokenOut, acs().cachedAddress, amountToPay);
                }
                // cache amount
                ncs().amount = amountToPay;
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
                if (cache > 46) {
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    _data = _data[25:];
                    amountToSwap = swapExactIn(amountToSwap, _data);
                    // re-assign tokenOut
                    tokenOut = getLastToken(_data);
                    cache = _data.length;
                }
                // slice out the end flag
                _data = _data[(cache - 1):cache];
                // cache amount
                ncs().amount = amountToSwap;
                address user = acs().cachedAddress;
                // 6 is mint / deposit
                if (tradeId == 6) {
                    _lendingPool.deposit(tokenOut, amountToSwap, user, 0);
                } else {
                    // tradeId minus 6 yields the interest rate mode
                    tradeId -= 6;
                    _lendingPool.repay(tokenOut, amountToSwap, tradeId, user);
                }

                // fetch the flag for closing the trade

                cache = uint8(bytes1(_data));
                // 1,2 are is borrow
                if (cache < 3) {
                    // the interest mode matches the cache in this case
                    _lendingPool.borrow(tokenIn, amountToRepayToPool, cache, 0, user);
                    _transferERC20Tokens(tokenIn, msg.sender, amountToRepayToPool);
                } else {
                    // withraw and send funds to the pool
                    _transferERC20TokensFrom(aas().aTokens[tokenIn], user, address(this), amountToRepayToPool);
                    _lendingPool.withdraw(tokenIn, amountToRepayToPool, msg.sender);
                }
            } else {
                // exact out
                (uint256 amountInLastPool, uint256 amountToSupply) = amount0Delta > 0
                    ? (uint256(amount0Delta), uint256(-amount1Delta))
                    : (uint256(amount1Delta), uint256(-amount0Delta));
                address user = acs().cachedAddress;
                // 3 is deposit
                if (tradeId == 3) {
                    _lendingPool.deposit(tokenIn, amountToSupply, user, 0);
                } else {
                    // 4, 5 are repay - subtracting 3 yields the interest rate mode
                    tradeId -= 3;
                    _lendingPool.repay(tokenIn, amountToSupply, tradeId, user);
                }
                uint256 cache = _data.length;
                // multihop if required
                if (cache > 46) {
                    _data = _data[25:];
                    flashSwapExactOutInternal(amountInLastPool, msg.sender, _data);
                } else {
                    // cache amount
                    ncs().amount = amountInLastPool;
                    // fetch the flag for closing the trade
                    _data = _data[(cache - 1):cache];
                    // assign end flag to cache
                    cache = uint8(bytes1(_data));
                    // borrow to pay pool
                    if (cache < 3) {
                        _lendingPool.borrow(tokenOut, amountInLastPool, cache, 0, user);
                        _transferERC20Tokens(tokenOut, msg.sender, amountInLastPool);
                    } else {
                        _transferERC20TokensFrom(aas().aTokens[tokenOut], user, address(this), amountInLastPool);
                        _lendingPool.withdraw(tokenOut, amountInLastPool, msg.sender);
                    }
                }
            }
            return;
        }
    }

    function getAmountOutUniV2(
        address pair,
        address tokenIn, // only used for velo
        bool zeroForOne,
        uint256 sellAmount,
        uint256 _pId // to identify the fee
    ) private view returns (uint256 buyAmount) {
        assembly {
            // Compute the buy amount based on the pair reserves.
            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch _pId
                case 50 {
                    // Call pair.getReserves(), store the results at `0xC00`
                    mstore(0xB00, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x4, 0xC00, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) {
                        revert(0, 0)
                    }

                    let sellReserve
                    let buyReserve
                    switch iszero(zeroForOne)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // fusionX v2 feeAm: 998
                    let sellAmountWithFee := mul(sellAmount, 998)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                case 51 {
                    // Call pair.getReserves(), store the results at `0xC00`
                    mstore(0xB00, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x4, 0xC00, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) {
                        revert(0, 0)
                    }

                    let sellReserve
                    let buyReserve
                    switch iszero(zeroForOne)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    // merchant moe feeAm: 997
                    let sellAmountWithFee := mul(sellAmount, 997)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 1000)))
                }
                default {
                    // selector for getAmountOut(uint256,address)
                    mstore(0xB00, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(0xB04, sellAmount)
                    mstore(0xB24, tokenIn)
                    if iszero(staticcall(gas(), pair, 0xB00, 0x44, 0xB00, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    buyAmount := mload(0xB00)
                }
            }
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

    // The uniswapV2 style callback for Velocimeter
    function hook(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        _uniswapV2StyleCallback(amount0, amount1, data);
    }

    // The general uniswapV2 style callback
    function _uniswapV2StyleCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) private {
        uint8 tradeId;
        address tokenIn;
        address tokenOut;
        bool zeroForOne;
        uint8 identifier;
        // the fee parameter in the path can be ignored for validating a V2 pool
        assembly {
            let firstWord := calldataload(data.offset)
            tokenIn := shr(96, firstWord)
            identifier := shr(64, firstWord) // swap pool identifier
            tradeId := shr(56, firstWord) // interaction identifier
            tokenOut := shr(96, calldataload(add(data.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }
        // calculate pool address
        address pool = pairAddress(tokenIn, tokenOut, identifier);
        {
            // validate sender
            require(msg.sender == pool);
        }
        // exact in is handled outside a callback
        if (tradeId == 0) return;
        else if (tradeId == 1) {
            // fetch amountOut
            uint256 referenceAmount = zeroForOne ? amount0 : amount1;
            // calculte amountIn
            referenceAmount = getV2AmountInDirect(pool, tokenIn, tokenOut, referenceAmount, identifier);
            uint256 cache = data.length;
            // either initiate the next swap or pay
            if (cache > 46) {
                data = data[25:];
                flashSwapExactOutInternal(referenceAmount, msg.sender, data);
            } else {
                // re-assign identifier
                data = data[(cache - 1):cache];
                // assign end flag to cache
                cache = uint8(bytes1(data));

                if (cache < 3) {
                    // borrow and repay pool
                    _lendingPool.borrow(tokenOut, referenceAmount, cache, 0, acs().cachedAddress);
                    _transferERC20Tokens(tokenOut, msg.sender, referenceAmount);
                } else if (cache < 8) {
                    // ids 3-7 are reserved
                    // withraw and send funds to the pool
                    _transferERC20TokensFrom(aas().aTokens[tokenOut], acs().cachedAddress, address(this), referenceAmount);
                    _lendingPool.withdraw(tokenOut, referenceAmount, msg.sender);
                } else {
                    // otherwise, just transfer it from cached address
                    pay(tokenOut, acs().cachedAddress, referenceAmount);
                }
                // cache amount
                ncs().amount = referenceAmount;
            }
            return;
        }
        if (tradeId > 5) {
            uint256 cache = data.length;
            // the swap amount is expected to be the nonzero output amount
            // since v2 does not send the input amount as parameter, we have to fetch
            // the other amount manually through the cache
            (uint256 amountToSwap, uint256 amountToBorrow) = zeroForOne ? (amount1, ncs().amount) : (amount0, ncs().amount);
            if (cache > 46) {
                // we need to swap to the token that we want to supply
                // the router returns the amount that we can finally supply to the protocol
                data = data[25:];
                amountToSwap = swapExactIn(amountToSwap, data);
                // supply directly
                tokenOut = getLastToken(data);
                cache = data.length;
            }
            // slice out the end flag
            data = data[(cache - 1):cache];
            // cache amount
            ncs().amount = amountToSwap;
            address user = acs().cachedAddress;
            // 6 is mint / deposit
            if (tradeId == 6) {
                // deposit funds for id == 6
                _lendingPool.deposit(tokenOut, amountToSwap, user, 0);
            } else {
                // repay - tradeId is irMode plus 6
                tradeId -= 6;
                _lendingPool.repay(tokenOut, amountToSwap, tradeId, user);
            }

            // assign end flag to tradeId
            tradeId = uint8(bytes1(data));
            // 1,2 are is borrow
            if (tradeId < 3) {
                _lendingPool.borrow(tokenIn, amountToBorrow, tradeId, 0, user);
                _transferERC20Tokens(tokenIn, msg.sender, amountToBorrow);
            } else {
                // withraw and send funds to the pool
                _transferERC20TokensFrom(aas().aTokens[tokenIn], user, address(this), amountToBorrow);
                _lendingPool.withdraw(tokenIn, amountToBorrow, msg.sender);
            }
        } else {
            // fetch amountOut
            uint256 referenceAmount = zeroForOne ? amount0 : amount1;
            address user = acs().cachedAddress;
            // 3 is deposit
            if (tradeId == 3) {
                _lendingPool.deposit(tokenIn, referenceAmount, user, 0);
            } else {
                // 4, 5 are repay, subtracting 3 yields the interest rate mode
                tradeId -= 3;
                _lendingPool.repay(tokenIn, referenceAmount, tradeId, user);
            }
            // calculate amountIn
            referenceAmount = getV2AmountInDirect(pool, tokenIn, tokenOut, referenceAmount, identifier);
            uint256 cache = data.length;
            // constinue swapping if more data is provided
            if (cache > 46) {
                data = data[25:];
                flashSwapExactOutInternal(referenceAmount, msg.sender, data);
            } else {
                // cache amount
                ncs().amount = referenceAmount;
                // slice out the end flag
                data = data[(cache - 1):cache];
                // assign end flag to cache
                cache = uint8(bytes1(data));
                // borrow to pay pool
                if (cache < 3) {
                    _lendingPool.borrow(tokenOut, referenceAmount, cache, 0, user);
                    _transferERC20Tokens(tokenOut, msg.sender, referenceAmount);
                } else {
                    _transferERC20TokensFrom(aas().aTokens[tokenOut], user, address(this), referenceAmount);
                    _lendingPool.withdraw(tokenOut, referenceAmount, msg.sender);
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

    // a flash swap where the output is sent to msg.sender
    function flashSwapExactOutInternal(uint256 amountOut, address receiver, bytes calldata data) internal {
        address tokenIn;
        address tokenOut;
        uint8 identifier;
        bool zeroForOne;
        assembly {
            let firstWord := calldataload(data.offset)
            tokenOut := shr(96, firstWord)
            identifier := shr(64, firstWord)
            tokenIn := shr(96, calldataload(add(data.offset, 25)))
            zeroForOne := lt(tokenIn, tokenOut)
        }

        // uniswapV3 style
        if (identifier < 50) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(data.offset)), 0xffffff)   
            }
            getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swap(
                receiver,
                zeroForOne,
                -int256(amountOut),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                data
            );
        }
        // uniswapV2 style
        else if (identifier < 100) {
            // get next pool
            tokenIn = pairAddress(tokenIn, tokenOut, identifier);
            // amountOut0, cache
            (uint256 amountOut0, uint256 amountOut1) = zeroForOne ? (uint256(0), amountOut) : (amountOut, uint256(0));
            IUniswapV2Pair(tokenIn).swap(amountOut0, amountOut1, address(this), data); // cannot swap to sender due to flashSwap
            tokenIn = receiver;
            if (tokenIn != address(this)) _transferERC20Tokens(tokenOut, tokenIn, amountOut);
        }
        // iZi
        else if (identifier == 100) {
            uint24 fee;
            assembly {
                fee := and(shr(72, calldataload(data.offset)), 0xffffff)
            }
            if (zeroForOne)
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapX2YDesireY(
                    receiver,
                    uint128(amountOut),
                    -800001,
                    data
                );
            else
                getUniswapV3Pool(tokenIn, tokenOut, fee, identifier).swapY2XDesireX(
                    receiver,
                    uint128(amountOut),
                    800001,
                    data
                );
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
        if (payer == address(0)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            _transferERC20Tokens(token, msg.sender, value);
        } else {
            // pull payment
            _transferERC20TokensFrom(token, payer, msg.sender, value);
        }
    }
}
