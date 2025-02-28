// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {FlashAccountBase} from "../FlashAccountBase.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {Benqi} from "./lendingProviders/Benqi/Benqi.sol";
import {IUniswapV3SwapCallback} from "@uniswap-v3-core/interfaces/callback/IUniswapV3FlashCallback.sol";

contract FlashAccount is FlashAccountBase, Benqi, IUniswapV3SwapCallback {
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

    // Aave V3 pool ethereum mainnet
    address internal constant AAVE_V3 = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    constructor(IEntryPoint entryPoint_) FlashAccountBase(entryPoint_) {}

    /**
     * @dev Explicit flash loan callback functions
     * All of them are locked through the execution lock to prevent access outside
     * of the `execute` functions
     */

    /**
     * Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * Balancer flash loan
     */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Morpho flash loan
     */
    function onMorphoFlashLoan(uint256 assets, bytes calldata params) external requireInExecution {
        // execute furhter operations
        _decodeAndExecute(params);
    }

    /**
     * Uniswap V3 related functions
     */

    struct SwapParams {
        address sender;
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
        bytes data;
    }

    /// @notice Requires requireInExecution, can't called directly, should validate the caller to be uniV3 pool
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external requireInExecution {
        // validate the caller to be uniV3 pool
        // Todo: implement
    }
}
