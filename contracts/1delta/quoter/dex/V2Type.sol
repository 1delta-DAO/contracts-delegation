// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.28;

abstract contract V2TypeQuoter {
    uint256 internal constant SCALE_18 = 1e18;

    /// @dev calculate amountOut for uniV2 style pools - does not require overflow checks
    function getV2TypeAmountOut(
        address pair,
        address tokenIn, // only used for solidly forks
        address tokenOut,
        uint256 sellAmount,
        uint256 feeDenom,
        uint256 _pId // to identify the fee
    ) internal view returns (uint256 buyAmount) {
        assembly {
            // Compute the buy amount based on the pair reserves.
            {
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch lt(_pId, 120)
                case 1 {
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
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0xC00)
                        buyReserve := mload(0xC20)
                    }
                    default {
                        sellReserve := mload(0xC20)
                        buyReserve := mload(0xC00)
                    }
                    let sellAmountWithFee := mul(sellAmount, feeDenom)
                    buyAmount := div(mul(sellAmountWithFee, buyReserve), add(sellAmountWithFee, mul(sellReserve, 10000)))
                }
                // covers solidly: velo volatile, stable and cleo V1 volatile, stable, stratum volatile, stable
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

    /**
     * Calculates the input amount for a UniswapV2 and Solidly style swap
     * This function is separate from the swapper because it is needed
     * in the spot case where we iteratively execute swaps between the
     * calculation of the amount and the execution of the v2 swap.
     * Compatible with solidly stable swaps.
     * We assume that the pair address is already provided.
     * We split dexIds
     * -> 100-135: Uniswap V2 / Solidly Volatile
     * -> 135-150: Solidly Stable
     * @param pair provided pair address
     * @param tokenIn input
     * @param tokenOut output
     * @param buyAmount output amunt
     * @param pId DEX identifier
     * @return x input amount
     */
    function getV2TypeAmountIn(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 feeDenom,
        uint256 pId // poolId
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `screp space`
            mstore(0x0, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
            if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // Revert if the pair contract does not return at least two words.
            if lt(returndatasize(), 0x40) {
                revert(0, 0)
            }

            // Compute the sell amount based on the pair reserves.
            {
                switch lt(pId, 135)
                case 1 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 0 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0x20)
                        buyReserve := mload(0x0)
                    }
                    default {
                        sellReserve := mload(0x0)
                        buyReserve := mload(0x20)
                    }
                    // we ensure that the pair has enough funds
                    if gt(buyAmount, buyReserve) {
                        revert(0, 0)
                    }

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                feeDenom // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // covers solidly forks for stable pools (>=135)
                default {
                    let _decimalsIn
                    let _decimalsOut_xy
                    let y0
                    let _reserveInScaled
                    // scope for scaled reserves
                    {
                        /////////////////////////////////////////////////////////////
                        // We fetch the decimals of the tokens to compute the curve
                        // style logic we do this in the scrap space
                        /////////////////////////////////////////////////////////////
                        // selector for decimals()
                        mstore(0x0, 0x313ce56700000000000000000000000000000000000000000000000000000000)
                        pop(staticcall(gas(), tokenIn, 0x0, 0x4, 0x4, 0x20))
                        _decimalsIn := exp(10, mload(0x4))
                        pop(staticcall(gas(), tokenOut, 0x0, 0x4, 0x4, 0x20))
                        _decimalsOut_xy := exp(10, mload(0x4))

                        // Call pair.getReserves(), store the results in scrap space
                        mstore(0x0, 0x0902f1ac00000000000000000000000000000000000000000000000000000000)
                        if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
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
                            _reserveInScaled := div(mul(mload(0x0), SCALE_18), _decimalsIn)
                            let buyReserve := mload(0x20)
                            // we ensure that the pair has enough funds
                            if gt(buyAmount, buyReserve) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(buyReserve, SCALE_18), _decimalsOut_xy)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(0x20), SCALE_18), _decimalsIn)
                            let buyReserve := mload(0x0)
                            // we ensure that the pair has enough funds
                            if gt(buyAmount, buyReserve) {
                                revert(0, 0)
                            }
                            _reserveOutScaled := div(mul(buyReserve, SCALE_18), _decimalsOut_xy)
                        }
                        y0 := sub(_reserveOutScaled, div(mul(buyAmount, SCALE_18), _decimalsOut_xy))
                        x := _reserveInScaled
                        // get xy
                        _decimalsOut_xy := div(
                            mul(
                                div(mul(_reserveInScaled, _reserveOutScaled), SCALE_18),
                                add(
                                    div(mul(_reserveInScaled, _reserveInScaled), SCALE_18), //
                                    div(mul(_reserveOutScaled, _reserveOutScaled), SCALE_18)
                                )
                            ),
                            SCALE_18
                        )
                    }
                    // for-loop for approximation
                    let i := 0
                    for {

                    } lt(i, 255) {

                    } {
                        let x_prev := x
                        let k := add(
                            div(mul(x, div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)), SCALE_18),
                            div(mul(y0, div(mul(div(mul(x, x), SCALE_18), x), SCALE_18)), SCALE_18)
                        )
                        switch lt(k, _decimalsOut_xy)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy, k), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
                                        div(
                                            mul(div(mul(y0, y0), SCALE_18), y0), //
                                            SCALE_18
                                        )
                                    )
                                )
                            )
                        }
                        default {
                            x := sub(
                                x,
                                div(
                                    mul(sub(k, _decimalsOut_xy), SCALE_18),
                                    add(
                                        div(
                                            mul(mul(3, y0), div(mul(x, x), SCALE_18)), //
                                            SCALE_18
                                        ),
                                        div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)
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
                    // calculate and adjust the result (reserveInNew - reserveIn) * 10k / (10k - fee)
                    x := add(
                        div(
                            div(
                                mul(mul(sub(x, _reserveInScaled), _decimalsIn), 10000),
                                feeDenom // 10000 - fee
                            ),
                            SCALE_18
                        ),
                        1 // rounding up
                    )
                }
            }
        }
    }
}
