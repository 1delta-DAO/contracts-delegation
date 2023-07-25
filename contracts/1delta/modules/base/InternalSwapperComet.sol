// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import {MarginCallbackData} from "../../dataTypes/CometInputTypes.sol";
import {IPool} from "../../interfaces/IAAVEV3Pool.sol";
import {Path} from "../../libraries/Path.sol";
import {SafeCast} from "../../dex-tools/uniswap/libraries/SafeCast.sol";
import {IUniswapV3Pool} from "../../dex-tools/uniswap/core/IUniswapV3Pool.sol";
import {PoolAddress} from "../../dex-tools/uniswap/libraries/PoolAddress.sol";
import {WithStorageComet} from "../../storage/CometBrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Money market module
 * @notice Allows users to chain a single money market transaction with a swap.
 * Direct lending pool interactions are unnecessary as the user can directly interact with the lending protocol
 * @author Achthar
 */
contract InternalSwapperComet is WithStorageComet {
    using Path for bytes;
    using SafeCast for uint256;

    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal immutable MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal immutable MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    bytes32 private immutable UNI_FF_FACTORY_ADDRESS;
    /// @dev Mask of lower 20 bytes.
    uint256 private constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 private constant UINT24_MASK = 0xffffff;

    constructor(address uniFactory) {
        UNI_FF_FACTORY_ADDRESS = bytes32((uint256(0xff) << 248) | (uint256(uint160(uniFactory)) << 88));
    }

    // Compute the pool address given two tokens and a fee.
    function _toPool(
        address inputToken,
        uint24 fee,
        address outputToken
    ) internal view returns (IUniswapV3Pool pool) {
        // address(keccak256(abi.encodePacked(
        //     hex"ff",
        //     UNI_FACTORY_ADDRESS,
        //     keccak256(abi.encode(inputToken, outputToken, fee)),
        //     UNI_POOL_INIT_CODE_HASH
        // )))
        bytes32 ffFactoryAddress = UNI_FF_FACTORY_ADDRESS;
        bytes32 poolInitCodeHash = PoolAddress.POOL_INIT_CODE_HASH;
        (address token0, address token1) = inputToken < outputToken ? (inputToken, outputToken) : (outputToken, inputToken);
        assembly {
            let s := mload(0x40)
            let p := s
            mstore(p, ffFactoryAddress)
            p := add(p, 21)
            // Compute the inner hash in-place
            mstore(p, token0)
            mstore(add(p, 32), token1)
            mstore(add(p, 64), and(UINT24_MASK, fee))
            mstore(p, keccak256(p, 96))
            p := add(p, 32)
            mstore(p, poolInitCodeHash)
            pool := and(ADDRESS_MASK, keccak256(s, 85))
        }
    }

    function exactInputToSelf(uint256 amountIn, bytes memory path) internal returns (uint256 amountOut) {
        while (true) {
            bool hasMultiplePools = path.hasMultiplePools();

            MarginCallbackData memory exactInputData;
            exactInputData.path = path.getFirstPool();
            exactInputData.tradeType = 99;
            (address tokenIn, address tokenOut, uint24 fee) = exactInputData.path.decodeFirstPool();

            bool zeroForOne = tokenIn < tokenOut;
            (int256 amount0, int256 amount1) = _toPool(tokenIn, fee, tokenOut).swap(
                address(this),
                zeroForOne,
                amountIn.toInt256(),
                zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
                abi.encode(exactInputData)
            );

            amountIn = uint256(-(zeroForOne ? amount1 : amount0));

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                path = path.skipToken();
            } else {
                amountOut = amountIn;
                break;
            }
        }
    }
}
