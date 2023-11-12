// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

// instead of an enum, we use uint8 to pack the trade type together with user and interestRateMode for a single slot
// the tradeType maps according to the following struct
// enum MarginTradeType {
//     // // One-sided loan and collateral operations
//     // SWAP_BORROW_SINGLE=0,
//     // SWAP_COLLATERAL_SINGLE=1,
//     // SWAP_BORROW_MULTI_EXACT_IN=2,
//     // SWAP_BORROW_MULTI_EXACT_OUT=3,
//     // SWAP_COLLATERAL_MULTI_EXACT_IN=4,
//     // SWAP_COLLATERAL_MULTI_EXACT_OUT=5,
//     // // Two-sided operations
//     // OPEN_MARGIN_SINGLE=6,
//     // TRIM_MARGIN_SINGLE=7,
//     // OPEN_MARGIN_MULTI_EXACT_IN=8,
//     // OPEN_MARGIN_MULTI_EXACT_OUT=9,
//     // TRIM_MARGIN_MULTI_EXACT_IN=10,
//     // TRIM_MARGIN_MULTI_EXACT_OUT=11,
//     // // the following are only used internally
//     // UNISWAP_EXACT_OUT=12,
//     // UNISWAP_EXACT_OUT_BORROW=13,
//     // UNISWAP_EXACT_OUT_WITHDRAW=14
// }

// margin swap input
struct MarginCallbackData {
    bytes path;
    // determines how to interact with the lending protocol
    uint8 tradeType;
    // determines the specific money market protocol
    uint8 interestRateMode;
    // signals whether the swap is exact in/out
    bool exactIn;
}

struct ExactInputCollateralMultiParams {
    bytes path;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct ExactOutputCollateralMultiParams {
    bytes path;
    uint256 amountOut;
    uint256 amountInMaximum;
}

struct ExactInputMultiParams {
    bytes path;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint8 interestRateMode;
}

struct ExactOutputMultiParams {
    bytes path;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint8 interestRateMode;
}

struct MarginSwapParamsMultiExactIn {
    bytes path;
    uint8 interestRateMode;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct MoneyMarketParamsMultiExactIn {
    bytes path;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint8 interestRateMode;
    address recipient;
}

struct CollateralParamsMultiExactIn {
    bytes path;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct CollateralParamsMultiNativeExactIn {
    bytes path;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct CollateralWithdrawParamsMultiExactIn {
    bytes path;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct MarginSwapParamsMultiExactOut {
    bytes path;
    uint8 interestRateMode;
    uint256 amountOut;
    uint256 amountInMaximum;
}

struct MarginSwapParamsNativeInExactOut {
    bytes path;
    uint8 interestRateMode;
    uint256 amountOut;
}

struct CollateralParamsNativeInExactOut {
    bytes path;
    uint256 amountOut;
}

struct CollateralParamsMultiExactOut {
    bytes path;
    uint256 amountOut;
    uint256 amountInMaximum;
}

struct ExactOutputUniswapParams {
    bytes path;
    address recipient;
    uint256 amountOut;
    address user;
    uint8 interestRateMode;
    uint8 tradeType;
    uint256 maximumInputAmount;
}

struct StandaloneExactInputUniswapParams {
    bytes path;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

// all in / out parameters

struct AllInputCollateralMultiParamsBase {
    bytes path;
    uint256 amountOutMinimum;
}

struct AllInputMultiParamsBase {
    bytes path;
    uint256 amountOutMinimum;
    uint8 interestRateMode;
}

struct AllOutputMultiParamsBase {
    bytes path;
    uint256 amountInMaximum;
    uint8 interestRateMode;
}

struct AllInputMultiParamsBaseWithRecipient {
    bytes path;
    address recipient;
    uint256 amountOutMinimum;
    uint8 interestRateMode;
}

struct AllOutputMultiParamsBaseWithRecipient {
    bytes path;
    uint256 amountInMaximum;
    address recipient;
    uint8 interestRateMode;
}

struct AllInputCollateralMultiParamsBaseWithRecipient {
    bytes path;
    address recipient;
    uint256 amountOutMinimum;
}

struct AllOutputCollateralMultiParamsBaseWithRecipient {
    bytes path;
    address recipient;
    uint256 amountInMaximum;
}
