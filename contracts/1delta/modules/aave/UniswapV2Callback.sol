// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "../../../external-protocols/uniswapV2/core/interfaces/IUniswapV2Pair.sol";
import {TokenTransfer} from "./../../libraries/TokenTransfer.sol";

contract AaveUniswapV2Callback is TokenTransfer {
    address immutable v2Factory;

    constructor(address _factory) {
        v2Factory = _factory;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(tokenA, tokenB)),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
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
        address pool,
        bool zeroForOne
    ) internal view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut, ) = IUniswapV2Pair(pool).getReserves();
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
        address factory = v2Factory;
        bytes memory _path = data;
        uint256 tradeType = 99;
        address pool = pairFor(factory, tokenIn, tokenOut);
        assembly {
            tokenIn := div(mload(add(_path, 0x20)), 0x1000000000000000000000000)
            tokenOut := div(mload(add(add(_path, 0x20), 0x20)), 0x1000000000000000000000000)
        }
        bool zeroForOne = tokenIn < tokenOut;
        require(msg.sender == pool);

        // EXACT IN
        if (tradeType == 99) {
            uint256 amountToPay = zeroForOne ? amount0 : amount1;
            _transferERC20Tokens(tokenIn, msg.sender, amountToPay);
        }
        // EXACT OUT
        else if (tradeType == 14) {
            uint256 amountOut = zeroForOne ? amount0 : amount1;

            uint256 amountOutNext = getAmountInByPool(amountOut, pool, zeroForOne);
            IUniswapV2Pair(pool).swap(amountOutNext, amountOutNext, address(this), data);
        }
    }
}
