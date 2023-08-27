// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;

import {
    MarginCallbackData,
    ExactInputMultiParams,
    ExactOutputMultiParams,
    MarginSwapParamsMultiExactIn,
    MarginSwapParamsMultiExactOut,
    ExactInputCollateralMultiParams,
    CollateralParamsMultiExactOut
 } from "../../dataTypes/InputTypes.sol";
import "../../../external-protocols/uniswapV2/core/interfaces/IUniswapV2Pair.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {Path} from "../../libraries/Path.sol";
import {WithStorage} from "../../storage/BrokerStorage.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";

contract AaveUniswapV2Callback is TokenTransfer, WithStorage {
    using Path for bytes;
    error Slippage();

    address immutable v2Factory;
    IPool private immutable _aavePool;

    uint256 private constant DEFAULT_AMOUNT_CACHED = type(uint256).max;

    constructor(address _factory, address aavePool) {
        v2Factory = _factory;
        _aavePool = IPool(aavePool);
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) internal view returns (address pair) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            v2Factory,
                            keccak256(abi.encodePacked(tokenA, tokenB)),
                            hex"f2a343db983032be4e17d2d9d614e0dd9a305aed3083e6757c5bb8e2ab607abe" // init code hash
                        )
                    )
                )
            )
        );
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountOutByPool(
        uint256 amountIn,
        IUniswapV2Pair pool,
        bool zeroForOne
    ) internal view returns (uint256 amountOut) {
        (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();
        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    function getAmountInByPool(
        uint256 amountOut,
        IUniswapV2Pair pool,
        bool zeroForOne
    ) internal view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut, ) = pool.getReserves();
        (reserveIn, reserveOut) = zeroForOne ? (reserveIn, reserveOut) : (reserveOut, reserveIn);
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // path is encoded as addresses glued together

    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        address tokenIn;
        address tokenOut;
        MarginCallbackData memory _data = abi.decode(data, (MarginCallbackData));
        uint256 tradeType = _data.tradeType;


        {
            bytes memory _path = _data.path;
            assembly {
                tokenIn := div(mload(add(_path, 0x20)), 0x1000000000000000000000000)
                tokenOut := div(mload(add(add(_path, 0x20), 23)), 0x1000000000000000000000000)
            }
        }
        
        bool zeroForOne = tokenIn < tokenOut;
        address pool = pairFor(tokenIn, tokenOut);
        { 
            require(msg.sender == pool);
        }

        // get aave pool
        IPool aavePool = _aavePool;
        if (tradeType == 4) {
            if (_data.exactIn) {
                (address token0, address token1) = sortTokens(tokenIn, tokenOut);
                // the swap amount is expected to be the nonzero output amount
                // since v2 does not send the input amount as argument, we have to fetch
                // the other amount manually through balanceOf
                (uint256 amountToSwap, uint256 amountToWithdraw) = amount0 > 0
                    ? (amount0, IERC20(token1).balanceOf(address(this)))
                    : (amount1, IERC20(token0).balanceOf(address(this)));

                if (_data.path.length > 40) {
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    _data.path = _data.path.skipToken();
                    amountToSwap = exactInputToSelf(amountToSwap, _data.path);

                    // supply directly
                    tokenOut = _data.path.getLastToken();
                }
                // cache amount
                ncs().amount = amountToSwap;

                // aavePool.supply(tokenOut, amountToSwap, _data.user, 0);

                // withraw and send funds to the pool
                // _transferERC20TokensFrom(aas().aTokens[tokenIn], _data.user, address(this), amountToWithdraw);
                aavePool.withdraw(tokenIn, amountToWithdraw, msg.sender);
            } else {
                uint256 amountToSupply = zeroForOne ? amount0 : amount1;
                uint256 amountInLastPool;
                IUniswapV2Pair pair = IUniswapV2Pair(pool);
                amountInLastPool = getAmountInByPool(amountToSupply, pair, zeroForOne);

                // we supply the amount received directly - together with user provided amount
                // aavePool.supply(tokenIn, amountToSupply, _data.user, 0);
                // we then swap exact out where the first amount is
                // borrowed and paid from the money market
                // the received amount is paid back to the original pool
                if (_data.path.hasMultiplePools()) {
                    _data.path = _data.path.skipToken();
                    (tokenOut, tokenIn, ) = _data.path.decodeFirstPool();
                    _data.tradeType = 14;
                    (uint256 amount0Out, uint256 amount1Out) = zeroForOne ? (amountInLastPool, uint256(0)) :
                         (uint256(0), amountInLastPool);
                    IUniswapV2Pair(pairFor(tokenIn, tokenOut)).swap(amount0Out, amount1Out, msg.sender, abi.encode(_data));
                } else {
                    // cache amount
                    ncs().amount = amountInLastPool;
                    // _transferERC20TokensFrom(aas().aTokens[tokenOut], _data.user, address(this), amountInLastPool);
                    aavePool.withdraw(tokenOut, amountInLastPool, msg.sender);
                }
            }
        }
        if (tradeType == 8) {
            if (_data.exactIn) {
                // (address token0, address token1) = sortTokens(tokenIn, tokenOut);
                // the swap amount is expected to be the nonzero output amount
                // since v2 does not send the input amount as argument, we have to fetch
                // the other amount manually through balanceOf
                (uint256 amountToSwap, uint256 amountToBorrow ) = amount0 > 0
                    ? (amount0, ncs().amount)
                    : (amount1, ncs().amount);
                if (_data.path.length > 43) {
                    // we need to swap to the token that we want to supply
                    // the router returns the amount that we can finally supply to the protocol
                    _data.path = _data.path.skipToken();
                    amountToSwap = exactInputToSelf(amountToSwap, _data.path);

                    // supply directly
                    tokenOut = _data.path.getLastToken();
                }
                // cache amount
                ncs().amount = amountToSwap;

                // aavePool.supply(tokenOut, amountToSwap, _data.user, 0);
                // aavePool.borrow(tokenIn, amountToBorrow, _data.interestRateMode, 0, _data.user);
                                // withraw and send funds to the pool
                _transferERC20Tokens(tokenIn, msg.sender, amountToBorrow);
            } else {
                uint256 amountToSupply = zeroForOne ? amount0 : amount1;
                uint256 amountInLastPool;
                IUniswapV2Pair pair = IUniswapV2Pair(pool);
                amountInLastPool = getAmountInByPool(amountToSupply, pair, zeroForOne);

                // we supply the amount received directly - together with user provided amount
                // aavePool.supply(tokenIn, amountToSupply, _data.user, 0);
                // we then swap exact out where the first amount is
                // borrowed and paid from the money market
                // the received amount is paid back to the original pool
                if (_data.path.hasMultiplePools()) {
                    _data.path = _data.path.skipToken();
                    (tokenOut, tokenIn, ) = _data.path.decodeFirstPool();
                    _data.tradeType = 14;
                    (uint256 amount0Out, uint256 amount1Out) = zeroForOne ? (amountInLastPool, uint256(0)) : 
                        (uint256(0), amountInLastPool);
                    IUniswapV2Pair(pairFor(tokenIn, tokenOut)).swap(amount0Out, amount1Out, msg.sender, abi.encode(_data));
                } else {
                    // cache amount
                    ncs().amount = amountInLastPool;
                    // _transferERC20TokensFrom(aas().aTokens[tokenOut], _data.user, address(this), amountInLastPool);
                    aavePool.withdraw(tokenOut, amountInLastPool, msg.sender);
                }
            }
        }
    }

    // requires the initial amount to have already been sent to the first pair
    // `refundETH` should be called at very end of all swaps
    function exactInputToSelf(uint256 amountIn, bytes memory path) internal returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, ) = path.decodeFirstPool();
        address pair = pairFor(tokenIn, tokenOut);
        _transferERC20Tokens(tokenIn, address(pair), amountIn);
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();
            (address token0, ) = sortTokens(tokenIn, tokenOut);
            // scope to avoid stack too deep errors
            {
                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(pair).getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                // calculate next amountIn
                amountIn = getAmountOut(amountIn, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = tokenIn == token0 ? (uint256(0), amountIn) : (amountIn, uint256(0));
            address to = hasMultiplePools ? pairFor(tokenIn, tokenOut) : address(this);
            IUniswapV2Pair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path.skipToken();
                // update pair
                pair = to;
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }

    // increase the margin position - borrow (tokenIn) and sell it against collateral (tokenOut)
    // the user provides the debt amount as input
    function openMarginPositionExactInV2(MarginSwapParamsMultiExactIn memory params) external returns (uint256 amountOut) {
        (address tokenIn, address tokenOut, ) = params.path.decodeFirstPool();

        MarginCallbackData memory data = MarginCallbackData({
            path: params.path,
            tradeType: 8,
            interestRateMode: params.interestRateMode,
            // user: msg.sender,
            exactIn: true
        });

        bool zeroForOne = tokenIn < tokenOut;
        ncs().amount = params.amountIn;
        (uint256 amount0Out, uint256 amount1Out) = zeroForOne ? (  uint256(0),
            getAmountOutByPool(params.amountIn,  IUniswapV2Pair(pairFor(tokenIn, tokenOut)), zeroForOne)) :
             ( getAmountOutByPool(params.amountIn,  IUniswapV2Pair(pairFor(tokenIn, tokenOut)), zeroForOne),  uint256(0));
        IUniswapV2Pair(pairFor(tokenIn, tokenOut)).swap(amount0Out, amount1Out, address(this), abi.encode(data));

        amountOut = ncs().amount;
        ncs().amount = DEFAULT_AMOUNT_CACHED;
        if (params.amountOutMinimum > amountOut) revert Slippage();
    }
}
