// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AddressesMantle} from "./CommonAddresses.f.sol";
import "forge-std/StdCheats.sol";
import {Script, console2} from "forge-std/Script.sol";
import "forge-std/console.sol";

interface IAll {
    function pairCodeHash() external view returns (bytes32);

    function factory() external view returns (address);

    function transfer(address a, uint b) external returns (bool);

    function decimals() external view returns (uint8);

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);

    function getAmountOut(uint amountIn, address tokenIn) external view returns (uint);

    function getFee(address pair) external view returns (uint256);
}

contract VelocimeterTest is AddressesMantle, Script, StdCheats {
    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 46560609, urlOrAlias: "https://rpc.ankr.com/mantle"});
    }

    function test_velo_pair_addr() external view {
        address p = pairAddress(WMNT, WETH, 52);
        address p2 = pairForOriginal(WMNT, WETH, false);
        console.log("poolAddress", p, p2);
        assert(p == p2);
    }

    function test_velo_swap_exact_in() external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e10);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountIn = 1e6; // 10
        uint amountOut = IAll(pair).getAmountOut(amountIn, tokenIn);
        console.log("Am true", amountOut);

        amountOut = getAmountOutWrapped(amountIn, tokenIn, token0, token1, pair);
        console.log("Am", amountOut);
        // IAll(tokenIn).transfer(pair, 0.1e18);
    }

    function test_velo_swap_exact_out() external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountOut = 1e6;
        console.log("out", amountOut);
        amountOut = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountOut);
        // IAll(tokenIn).transfer(pair, 0.1e18);
    }

    function getAmountOutWrapped(uint amountIn, address tokenIn, address token0, address token1, address pair) internal view returns (uint) {
        (uint112 _reserve0, uint112 _reserve1, ) = IAll(pair).getReserves();
        uint _decimals0 = 10 ** IAll(token0).decimals();
        uint _decimals1 = 10 ** IAll(token1).decimals();
        return getAmountOut(amountIn, tokenIn, token0, _reserve0, _reserve1, _decimals0, _decimals1, pair);
    }

    function getAmountInWrapped(uint amountOut, address tokenIn, address token0, address token1, address pair) internal view returns (uint) {
        (uint112 _reserve0, uint112 _reserve1, ) = IAll(pair).getReserves();
        uint _decimals0 = 10 ** IAll(token0).decimals();
        uint _decimals1 = 10 ** IAll(token1).decimals();
        return getAmountIn(amountOut, tokenIn, token0, _reserve0, _reserve1, _decimals0, _decimals1, pair);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairForOriginal(address tokenA, address tokenB, bool stable) public view returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        console.log("Bytes");
        console.logBytes(abi.encodePacked(token0, token1, stable));
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            veloFactory,
                            keccak256(abi.encodePacked(token0, token1, stable)),
                            VELO_CODE_HASH // init code hash
                        )
                    )
                )
            )
        );
    }

    /// @dev gets uniswapV2 (and fork) pair addresses
    function pairAddress(address tokenA, address tokenB, uint8 pId) internal pure returns (address pair) {
        uint256 _pId = pId;
        assembly {
            switch _pId
            // 52: Velo vola
            case 52 {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 0)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
            default {
                switch lt(tokenA, tokenB)
                case 0 {
                    mstore(0xB14, tokenA)
                    mstore(0xB00, tokenB)
                }
                default {
                    mstore(0xB14, tokenB)
                    mstore(0xB00, tokenA)
                }
                mstore8(0xB34, 1)
                let salt := keccak256(0xB0C, 0x29)
                mstore(0xB00, VELO_FF_FACTORY)
                mstore(0xB15, salt)
                mstore(0xB35, VELO_CODE_HASH)

                pair := and(ADDRESS_MASK, keccak256(0xB00, 0x55))
            }
        }
    }

    function new_getX(uint y0, uint xy, uint x) internal pure returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint x_prev = x;
            uint k = _f(x, y0);
            if (k < xy) {
                uint dx = ((xy - k) * 1e18) / _d_x(y0, x);
                x = x + dx;
            } else {
                uint dx = ((k - xy) * 1e18) / _d_x(y0, x);
                x = x - dx;
            }
            if (x > x_prev) {
                if (x - x_prev <= 1) {
                    return x;
                }
            } else {
                if (x_prev - x <= 1) {
                    return x;
                }
            }
        }
        return x;
    }

    function _f(uint x, uint y) internal pure returns (uint) {
        return (x * ((((y * y) / 1e18) * y) / 1e18)) / 1e18 + (((((x * x) / 1e18) * x) / 1e18) * y) / 1e18;
    }

    function _d_y(uint x0, uint y) internal pure returns (uint) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _d_x(uint y0, uint x) internal pure returns (uint) {
        return (3 * y0 * ((x * x) / 1e18)) / 1e18 + ((((y0 * y0) / 1e18) * y0) / 1e18);
    }

    function _get_y(uint x0, uint xy, uint y) internal view returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            // console.log("K", k);
            // console.log("xy", xy);
            if (k < xy) {
                uint dy = ((xy - k) * 1e18) / _d_y(x0, y);
                // console.log("dy", dy);
                y = y + dy;
            } else {
                uint dy = ((k - xy) * 1e18) / _d_y(x0, y);
                // console.log("dy", dy);
                y = y - dy;
            }
            if (y > y_prev) {
                // console.log("y > y_prev", y);
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                // console.log("y <= y_prev", y);
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function getAmountOut(
        uint amountIn,
        address tokenIn,
        address token0,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1,
        address pair
    ) internal view returns (uint) {
        amountIn -= (amountIn * IAll(veloFactory).getFee(pair)) / 10000; // remove fee from amount received
        console.log("AmountIn act", amountIn);
        return _getAmountOut(amountIn, tokenIn, token0, _reserve0, _reserve1, _decimals0, _decimals1);
    }

    function getAmountIn(
        uint amountOut,
        address tokenIn,
        address token0,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1,
        address pair
    ) internal view returns (uint) {
        amountOut = amountOut * (10000 - IAll(veloFactory).getFee(pair)); // add fee to amount received
        return _getAmountIn(amountOut, tokenIn, token0, _reserve0 * 10000, _reserve1 * 10000, _decimals0, _decimals1) / 10000 + 1;
    }

    function _getAmountOut(
        uint amountIn,
        address tokenIn,
        address token0,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1
    ) internal view returns (uint) {
        // if (stable) {
        uint xy = _k(_reserve0, _reserve1, _decimals0, _decimals1);
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        (uint reserveA, uint reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        amountIn = tokenIn == token0 ? (amountIn * 1e18) / _decimals0 : (amountIn * 1e18) / _decimals1;
        uint y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
        return (y * (tokenIn == token0 ? _decimals1 : _decimals0)) / 1e18;

        // } else {
        //     (uint reserveIn, uint reserveOut) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        //     return (amountIn * reserveOut) / (reserveIn + amountIn);
        // }
    }

    function _getAmountIn(
        uint amountOut,
        address tokenIn,
        address token0,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1
    ) internal view returns (uint) {
        // if (stable) {
        uint xy = _k(_reserve0, _reserve1, _decimals0, _decimals1);
        console.log("K", xy);
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        (uint reserveIn, uint reserveOut) = tokenIn != token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        amountOut = tokenIn != token0 ? (amountOut * 1e18) / _decimals0 : (amountOut * 1e18) / _decimals1;
        console.log("amountOut", amountOut);
        console.log("reserveOut", reserveOut);
        console.log("reserveIn", reserveIn);
        uint x = reserveIn - _get_y(reserveIn, xy, reserveOut - amountOut);
        console.log("x", x);
        return (x * (tokenIn != token0 ? _decimals1 : _decimals0)) / 1e18;
        // } else {
        //     (uint reserveIn, uint reserveOut) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        //     return (amountIn * reserveOut) / (reserveIn + amountIn);
        // }
    }

    function _k(uint x, uint y, uint _decimals0, uint _decimals1) internal view returns (uint) {
        // if (stable) {
        uint _x = (x * 1e18) / _decimals0;
        uint _y = (y * 1e18) / _decimals1;
        uint _a = (_x * _y) / 1e18;
        uint _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
        // } else {
        //     return x * y; // xy >= k
        // }
    }
}
