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

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
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
        IAll(tokenIn).transfer(pair, amountIn);
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
    }

    function test_velo_swap_exact_in_mix_o() external {
        address pair = pairAddress(axlUSDC, axlFRAX, 53);
        address tokenIn = axlUSDC;
        address tokenOut = axlFRAX;
        deal(tokenIn, address(this), 1e10);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountIn = 1e6; // 10
        uint amountOut = IAll(pair).getAmountOut(amountIn, tokenIn);
        console.log("Am true", amountOut);

        amountOut = getAmountOutWrapped(amountIn, tokenIn, token0, token1, pair);
        console.log("Am", amountOut);
        IAll(tokenIn).transfer(pair, amountIn);
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
    }

    function test_velo_swap_exact_in_vari(uint amountIn) external {
        amountIn = amountIn < 100 ? 100 : amountIn > 1e10 ? 1e10 : amountIn;
        console.log("Am in", amountIn);
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountOut = IAll(pair).getAmountOut(amountIn, tokenIn);
        console.log("Am true", amountOut);

        uint amountOutC = getAmountOutWrapped(amountIn, tokenIn, token0, token1, pair);
        assert(amountOutC == amountOut);
    }

    function test_velo_swap_exact_in_more() external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e10);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountIn = 35806667; // 10
        uint amountOut = IAll(pair).getAmountOut(amountIn, tokenIn);
        console.log("Am in true - more", amountIn);

        amountOut = getAmountOutWrapped(amountIn, tokenIn, token0, token1, pair);
        console.log("Am - more", amountOut);
        IAll(tokenIn).transfer(pair, amountIn);
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
    }

    function hook(address sender, uint amount0, uint amount1, bytes calldata data) external {}

    function test_velo_swap_exact_out(uint amountOut) external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 100 ? 100 : amountOut > 1e9 ? 1e9 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_inv(uint amountOut) external {
        // uint amountOut = 10000;
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDT;
        address tokenOut = USDC;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 10000 ? 10000 : amountOut > 1e9 ? 1e9 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_mix(uint amountOut) external {
        // uint amountOut = 995992696472419497;
        address pair = pairAddress(axlFRAX, axlUSDC, 53);
        address tokenIn = axlUSDC;
        address tokenOut = axlFRAX;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 1e13 ? 1e13 : amountOut > 1e20 ? 1e20 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_mix_inv(uint amountOut) external {
        address pair = pairAddress(axlFRAX, axlUSDC, 53);
        address tokenIn = axlFRAX;
        address tokenOut = axlUSDC;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 100 ? 100 : amountOut > 1e8 ? 1e8 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_mix_inv_o(uint amountOut) external {
        address pair = pairAddress(axlFRAX, axlUSDC, 53);
        address tokenIn = axlFRAX;
        address tokenOut = axlUSDC;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 100 ? 100 : amountOut > 1e8 ? 1e8 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped_o(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_mix_o() external {
        uint amountOut = 995992696472419497;
        address pair = pairAddress(axlFRAX, axlUSDC, 53);
        address tokenIn = axlUSDC;
        address tokenOut = axlFRAX;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 1e13 ? 1e13 : amountOut > 1e20 ? 1e20 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped_o(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_inv_o() external {
        uint amountOut = 10000;
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDT;
        address tokenOut = USDC;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        amountOut = amountOut < 10000 ? 10000 : amountOut > 1e9 ? 1e9 : amountOut; // bound(amountOut, 100, 100.0e6);
        vm.recordLogs();
        console.log("out", amountOut);
        uint amountIn = getAmountInWrapped_o(amountOut, tokenIn, token0, token1, pair);
        console.log("in", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_more() external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountOut = 35801795;
        vm.recordLogs();
        console.log("out - more", amountOut);
        uint amountIn = getAmountInWrapped(amountOut, tokenIn, token0, token1, pair);
        console.log("in - more", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_swap_exact_out_more_o() external {
        address pair = pairAddress(USDC, USDT, 53);
        address tokenIn = USDC;
        address tokenOut = USDT;
        deal(tokenIn, address(this), 1e40);
        (address token0, address token1) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);

        uint amountOut = 35801795;
        vm.recordLogs();
        console.log("out - more", amountOut);
        uint amountIn = getAmountInWrapped_o(amountOut, tokenIn, token0, token1, pair);
        console.log("in - more", amountIn);
        IAll(tokenIn).transfer(pair, amountIn);
        console.log("swap");
        IAll(pair).swap(tokenOut == token0 ? amountOut : 0, tokenOut == token1 ? amountOut : 0, address(this), "0x");
        console.log("swap complete");
    }

    function test_velo_loop() external view {
        uint _y0 = 1412642061000000000000;
        uint _xy = 7101217886410926127276352072866;
        uint _x = 1296962992000000000000;
        console.log("getX");
        uint o = new_getX(_y0, _xy, _x);
        console.log("o", o);
        uint n = new_getX_a(_y0, _xy, _x);
        console.log("n", n);
        assert(n == o);
    }

    function test_velo_f() external view {
        uint x = 213213321321;
        uint y = 48740834812604276470692694885616;
        uint f = _f(x, y);
        console.log("f", f);
        uint f_new = _f_a(x, y);
        assert(f_new == f);
    }

    function test_velo_dx() external view {
        uint x = 213213321321;
        uint y = 48740834812604276470692694885616;
        uint f = _d_x(y, x);
        console.log("f", f);
        uint f_new = _d_x_a(y, x);
        assert(f_new == f);
    }

    // FS

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
        return getAmountIn(amountOut, tokenIn, tokenIn == token0 ? token1 : token0, _reserve0, _reserve1, _decimals0, _decimals1, pair);
    }

    function getAmountInWrapped_o(uint amountOut, address tokenIn, address token0, address token1, address pair) internal view returns (uint) {
        (uint112 _reserve0, uint112 _reserve1, ) = IAll(pair).getReserves();
        uint _decimals0 = 10 ** IAll(token0).decimals();
        uint _decimals1 = 10 ** IAll(token1).decimals();
        return getAmountIn_o(amountOut, tokenIn, token0, _reserve0, _reserve1, _decimals0, _decimals1, pair);
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairForOriginal(address tokenA, address tokenB, bool stable) public view returns (address pair) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
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

    function new_getX(uint y0, uint xy, uint x) internal view returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint x_prev = x;
            uint k = _f(y0, x);
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
            if (k < xy) {
                uint dy = ((xy - k) * 1e18) / _d_y(x0, y);
                y = y + dy;
            } else {
                uint dy = ((k - xy) * 1e18) / _d_y(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
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
        return _getAmountOut(amountIn, tokenIn, token0, _reserve0, _reserve1, _decimals0, _decimals1);
    }

    function getAmountIn_o(
        uint amountOut,
        address tokenIn,
        address token0,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1,
        address pair
    ) internal view returns (uint) {
        return _getAmountIn(amountOut, tokenIn == token0, _reserve0, _reserve1, _decimals0, _decimals1, pair);
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
        return _getAmountIn_assembly(amountOut, tokenIn, token0, pair);
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
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        uint xy = _k(_reserve0, _reserve1);
        (uint reserveIn, uint reserveOut) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        amountIn = tokenIn == token0 ? (amountIn * 1e18) / _decimals0 : (amountIn * 1e18) / _decimals1;
        uint y = reserveOut - _get_y(amountIn + reserveIn, xy, reserveOut);
        return (y * (tokenIn == token0 ? _decimals1 : _decimals0)) / 1e18;
    }

    function _getAmountIn(
        uint amountOut,
        bool zeroForOne,
        uint _reserve0,
        uint _reserve1,
        uint _decimals0,
        uint _decimals1,
        address pair
    ) internal view returns (uint) {
        _reserve0 = (_reserve0 * 1e18) / _decimals0;
        _reserve1 = (_reserve1 * 1e18) / _decimals1;
        uint xy = _k(_reserve0, _reserve1);
        (uint reserveIn, uint reserveOut) = zeroForOne ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        amountOut = !zeroForOne ? (amountOut * 1e18) / _decimals0 : (amountOut * 1e18) / _decimals1;
        uint x = (new_getX(reserveOut - amountOut, xy, reserveIn) - reserveIn);
        return ((x * (zeroForOne ? _decimals0 : _decimals1)) * 10000) / (10000 - IAll(veloFactory).getFee(pair)) / 1e18 + 1;
    }

    function _getAmountIn_assembly(
        uint amountOut,
        address tokenIn,
        address tokenOut,
        address pair // stable pair
    ) internal view returns (uint x) {
        assembly {
            let ptr := mload(0x40)
            let _decimalsIn
            let _decimalsOut
            let xy
            let y0
            //  let x
            let _reserveInScaled
            {
                {
                    let ptrPlus4 := add(ptr, 0x4)
                    // selector for decimals()
                    mstore(ptr, 0x313ce56700000000000000000000000000000000000000000000000000000000)
                    pop(staticcall(gas(), tokenIn, ptr, 0x4, ptrPlus4, 0x20))
                    _decimalsIn := exp(10, mload(ptrPlus4))
                    pop(staticcall(gas(), tokenOut, ptr, 0x4, ptrPlus4, 0x20))
                    _decimalsOut := exp(10, mload(ptrPlus4))
                }

                // Call pair.getReserves(), store the results at `free memo`
                mstore(ptr, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                if iszero(staticcall(gas(), pair, ptr, 0x4, ptr, 0x40)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                // Revert if the pair contract does not return at least two words.
                if lt(returndatasize(), 0x40) {
                    revert(0, 0)
                }
                // assign reserves to in/out
                let _reserveOutScaled
                switch lt(tokenIn, tokenOut)
                case 1 {
                    _reserveInScaled := div(mul(mload(ptr), 1000000000000000000), _decimalsIn)
                    _reserveOutScaled := div(mul(mload(add(ptr, 0x20)), 1000000000000000000), _decimalsOut)
                }
                default {
                    _reserveInScaled := div(mul(mload(add(ptr, 0x20)), 1000000000000000000), _decimalsIn)
                    _reserveOutScaled := div(mul(mload(ptr), 1000000000000000000), _decimalsOut)
                }
                // get xy
                xy := div(
                    mul(
                        div(mul(_reserveInScaled, _reserveOutScaled), 1000000000000000000),
                        add(
                            div(mul(_reserveInScaled, _reserveInScaled), 1000000000000000000),
                            div(mul(_reserveOutScaled, _reserveOutScaled), 1000000000000000000)
                        )
                    ),
                    1000000000000000000
                )

                y0 := sub(_reserveOutScaled, div(mul(amountOut, 1000000000000000000), _decimalsOut))
                x := _reserveInScaled
            }
            // for-loop for approximation
            let i := 0
            for {

            } lt(i, 255) {

            } {
                let x_prev := x
                let k := add(
                    div(mul(x, div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)), 1000000000000000000),
                    div(mul(y0, div(mul(div(mul(x, x), 1000000000000000000), x), 1000000000000000000)), 1000000000000000000)
                )
                switch lt(k, xy)
                case 1 {
                    x := add(
                        x,
                        div(
                            mul(sub(xy, k), 1000000000000000000),
                            add(
                                div(mul(mul(3, y0), div(mul(x, x), 1000000000000000000)), 1000000000000000000),
                                div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)
                            )
                        )
                    )
                }
                default {
                    x := sub(
                        x,
                        div(
                            mul(sub(k, xy), 1000000000000000000),
                            add(
                                div(mul(mul(3, y0), div(mul(x, x), 1000000000000000000)), 1000000000000000000),
                                div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)
                            )
                        )
                    )
                }
                switch gt(x, x_prev)
                case 1 {
                    if lt(sub(x, x_prev), 2) {
                        break
                    }
                }
                default {
                    if lt(sub(x_prev, x), 2) {
                        break
                    }
                }
                i := add(i, 1)
            }
            // fetch the fee from the factory
            // selector for getFee(address)
            mstore(ptr, 0xb88c914800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), pair)
            pop(staticcall(gas(), VELO_FACOTRY, ptr, 0x24, ptr, 0x20))
            // calculate and adjust the result (reserveInNew - reserveIn) * 10k / (10k - fee)
            x := add(
                div(
                    div(
                        mul(mul(sub(x, _reserveInScaled), _decimalsIn), 10000),
                        sub(10000, mload(ptr)) // 10000 - fee
                    ),
                    1000000000000000000
                ),
                1
            )
        }
    }

    function _k(uint x, uint y) internal view returns (uint) {
        uint _a = (x * y) / 1e18;
        uint _b = ((x * x) / 1e18 + (y * y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    function _k_a(uint x, uint y, uint _decimals0, uint _decimals1) internal view returns (uint k) {
        assembly {
            let _x := div(mul(x, 1000000000000000000), _decimals0)
            let _y := div(mul(y, 1000000000000000000), _decimals1)
            let _a := div(mul(_x, _y), 1000000000000000000)
            let _b := add(div(mul(_x, _x), 1000000000000000000), div(mul(_y, _y), 1000000000000000000))
            k := div(mul(_a, _b), 1000000000000000000)
        }
    }

    function _f_a(uint x, uint y) internal pure returns (uint f) {
        assembly {
            f := add(
                div(mul(x, div(mul(div(mul(y, y), 1000000000000000000), y), 1000000000000000000)), 1000000000000000000), // y
                div(mul(y, div(mul(div(mul(x, x), 1000000000000000000), x), 1000000000000000000)), 1000000000000000000) // x
            )
        }
    }

    function _d_x_a(uint y0, uint x) internal pure returns (uint dx) {
        assembly {
            dx := add(
                div(mul(mul(3, y0), div(mul(x, x), 1000000000000000000)), 1000000000000000000),
                div(mul(div(mul(y0, y0), 1000000000000000000), y0), 1000000000000000000)
            )
        }
    }

    function new_getX_a(uint y0, uint xy, uint x) internal view returns (uint result) {
        assembly {
            let i := 0
            function _f(_x, _y) -> f {
                f := add(
                    div(mul(_x, div(mul(div(mul(_y, _y), 1000000000000000000), _y), 1000000000000000000)), 1000000000000000000),
                    div(mul(_y, div(mul(div(mul(_x, _x), 1000000000000000000), _x), 1000000000000000000)), 1000000000000000000)
                )
            }
            function _dx(_y, _x) -> dx_ {
                dx_ := add(
                    div(mul(mul(3, _y), div(mul(_x, _x), 1000000000000000000)), 1000000000000000000),
                    div(mul(div(mul(_y, _y), 1000000000000000000), _y), 1000000000000000000)
                )
            }
            for {

            } lt(i, 255) {

            } {
                let x_prev := x
                let k := _f(y0, x)
                switch lt(k, xy)
                case 1 {
                    let dx := div(mul(sub(xy, k), 1000000000000000000), _dx(y0, x))
                    x := add(x, dx)
                }
                default {
                    let dx := div(mul(sub(k, xy), 1000000000000000000), _dx(y0, x))
                    x := sub(x, dx)
                }
                switch gt(x, x_prev)
                case 1 {
                    if lt(sub(x, x_prev), 2) {
                        result := x
                        break
                    }
                }
                default {
                    if lt(sub(x_prev, x), 2) {
                        result := x
                        break
                    }
                }
                i := add(i, 1)
            }
        }
    }
}
