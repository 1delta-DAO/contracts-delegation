// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {V3TypeSwapper} from "./V3Type.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract UniTypeSwapper is V3TypeSwapper {
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    /// @dev used for some of the denominators in solidly calculations
    uint256 private constant SCALE_18 = 1.0e18;

    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;
    address internal constant CLEO_V1_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;
    address internal constant STRATUM_FACTORY = 0x061FFE84B0F9E1669A6bf24548E5390DBf1e03b2;

    constructor() {}

    /**
     * Swap exact out via v2 type pool
     * We always pay within the callback.
     * This requires us to manually transfer to the reciever
     * @param amountOut receive amount
     * @param maxIn maimum in to pass into callback
     * @param payer payer to pass into callback
     * @param receiver receiver address
     * @param path path calldata
     */
    function _swapV2StyleExactOut(
        address tokenA,
        address tokenB,
        address pair,
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        address receiver,
        bool useFlashSwap,
        bytes calldata path
    )
        internal
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // selector for swap(...)
            mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)

            switch lt(tokenA, tokenB)
            case 1 {
                mstore(add(ptr, 0x4), 0x0)
                mstore(add(ptr, 0x24), amountOut)
            }
            default {
                mstore(add(ptr, 0x4), amountOut)
                mstore(add(ptr, 0x24), 0x0)
            }
        
            // Prepare external call data
            switch useFlashSwap
            case 1 {
                // Store recipient
                mstore(add(ptr, 0x44), address())
                // Store data offset
                mstore(add(ptr, 0x64), 0x80)

                ////////////////////////////////////////////////////
                // We append amountIn (uint128) & payer (address) (36 bytes)
                // This is to prevent the re-calculation of amount in
                ////////////////////////////////////////////////////
                let pathLength := path.length
                // Store path
                calldatacopy(add(ptr, 164), path.offset, pathLength)

                mstore(add(add(ptr, 164), pathLength), shl(128, maxIn)) // store amountIn
                pathLength := add(pathLength, 32) // pad
                mstore(add(add(ptr, 164), pathLength), shl(96, payer))
                pathLength := add(pathLength, 20)
                /// Store updated data length
                mstore(add(ptr, 132), pathLength)

                // Perform the external 'swap' call
                if iszero(call(gas(), pair, 0, ptr, add(196, pathLength), ptr, 0x0)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                ////////////////////////////////////////////////////
                // We chain the transfer to the receiver, given that
                // it is not this address
                ////////////////////////////////////////////////////
                if iszero(eq(address(), receiver)) {
                    ////////////////////////////////////////////////////
                    // Populate tx for transfer to receiver
                    ////////////////////////////////////////////////////
                    // selector for transfer(address,uint256)
                    mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), receiver)
                    mstore(add(ptr, 0x24), amountOut)

                    let success := call(gas(), tokenB, 0, ptr, 0x44, ptr, 32)

                    let rdsize := returndatasize()

                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    success := and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                iszero(lt(rdsize, 32)), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )

                    if iszero(success) {
                        returndatacopy(0x0, 0, rdsize)
                        revert(0x0, rdsize)
                    }
                }
            }
            default {
                // Store recipient directly
                mstore(add(ptr, 0x44), receiver)
                // Store data offset
                mstore(add(ptr, 0x64), 0x80)
                ////////////////////////////////////////////////////
                // We store the bytes length to zero (no callback)
                // and directly trigger the swap
                ////////////////////////////////////////////////////
                mstore(add(ptr, 0x84), 0) // bytes length
                if iszero(call(
                    gas(),
                    pair,
                    0x0,
                    ptr, // input selector
                    0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                    0, // output = 0
                    0 // output size = 0
                )) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }

    /**
     * Calculates the input amount for a UniswapV2 and Solidly style swap
     * Assumes that the pair address has been pre-calculated
     * @param pair provided pair address
     * @param tokenIn input
     * @param tokenOut output
     * @param buyAmount output amunt
     * @param pId DEX identifier
     * @return x input amount
     */
    function getV2AmountInDirect(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 pId // poolId
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `free memo`
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
                switch pId
                case 100 {
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

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feeAm is 998 for fusionX
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 998)), 1)
                }
                // merchant moe
                case 101 {
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

                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 1000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // feAm is 997 for Moe
                    x := add(div(mul(mul(sellReserve, buyAmount), 1000), mul(sub(buyReserve, buyAmount), 997)), 1)
                }
                // velo volatile
                case 121 {
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
                    // fetch the fee from the factory
                    // selector for getFee(address)
                    mstore(0x0, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                    mstore(0x4, pair)
                    pop(staticcall(gas(), VELO_FACTORY, 0x0, 0x24, 0x0, 0x20))
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, mload(0x0)) // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // stratum volatile
                case 125 {
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
                    // fetch the fee from the factory
                    // selector for getFee(address)
                    mstore(0x0, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                    mstore(0x4, pair)
                    pop(staticcall(gas(), STRATUM_FACTORY, 0x0, 0x24, 0x0, 0x20))
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, mload(0x0)) // adjust for Velo fee
                            )
                        ),
                        1
                    )
                }
                // cleo V1 volatile
                case 123 {
                    let sellReserve
                    let buyReserve
                    switch lt(tokenIn, tokenOut)
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0x0)
                        buyReserve := mload(0x20)
                    }
                    default {
                        buyReserve := mload(0x0)
                        sellReserve := mload(0x20)
                    }
                    // revert if insufficient reserves
                    if lt(buyReserve, buyAmount) {
                        revert(0, 0)
                    }
                    // fetch the fee from the factory
                    // selector for pairFee(address)
                    mstore(0x0, 0x841fa66b00000000000000000000000000000000000000000000000000000000)
                    mstore(0x4, pair)
                    pop(staticcall(gas(), CLEO_V1_FACTORY, 0x0, 0x24, 0x0, 0x20))
                    let fee := mload(0x0)
                    // if the fee is zero, it will be overridden by the default ones
                    if iszero(fee) {
                        // selector for volatileFee()
                        mstore(0x0, 0x5084ed0300000000000000000000000000000000000000000000000000000000)
                        pop(staticcall(gas(), CLEO_V1_FACTORY, 0x0, 0x24, 0x0, 0x20))
                        fee := mload(0x0)
                    }
                    // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                    // x = (reserveIn * amountOut * 10000) /
                    //     ((reserveOut - amountOut) * feeAm) + 1;
                    // for Velo volatile, we fetch the fee
                    x := add(
                        div(
                            mul(mul(sellReserve, buyAmount), 10000),
                            mul(
                                sub(buyReserve, buyAmount),
                                sub(10000, fee) // adjust for Cleo fee
                            )
                        ),
                        1
                    )
                }
                // covers solidly forks for stable pools (53, 55, 57)
                default {
                    let _decimalsIn
                    let _decimalsOut_xy_fee
                    let y0
                    let _reserveInScaled
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
                        _decimalsOut_xy_fee := exp(10, mload(0x4))

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
                            _reserveOutScaled := div(mul(mload(0x20), SCALE_18), _decimalsOut_xy_fee)
                        }
                        default {
                            _reserveInScaled := div(mul(mload(0x20), SCALE_18), _decimalsIn)
                            _reserveOutScaled := div(mul(mload(0x0), SCALE_18), _decimalsOut_xy_fee)
                        }
                        y0 := sub(_reserveOutScaled, div(mul(buyAmount, SCALE_18), _decimalsOut_xy_fee))
                        x := _reserveInScaled
                        // get xy
                        _decimalsOut_xy_fee := div(
                            mul(
                                div(mul(_reserveInScaled, _reserveOutScaled), SCALE_18),
                                add(
                                    div(mul(_reserveInScaled, _reserveInScaled), SCALE_18),
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
                        switch lt(k, _decimalsOut_xy_fee)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy_fee, k), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
                                        div(mul(div(mul(y0, y0), SCALE_18), y0), SCALE_18)
                                    )
                                )
                            )
                        }
                        default {
                            x := sub(
                                x,
                                div(
                                    mul(sub(k, _decimalsOut_xy_fee), SCALE_18),
                                    add(
                                        div(mul(mul(3, y0), div(mul(x, x), SCALE_18)), SCALE_18),
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
                    // fetch the fee from the factory
                    // selector for getFee(address)
                    switch pId
                    // velo stable
                    case 122 {
                        mstore(0x0, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(0x4, pair)
                        pop(staticcall(gas(), VELO_FACTORY, 0x0, 0x24, 0x0, 0x20))
                        _decimalsOut_xy_fee := mload(0x0)
                    }
                    // stratum stable
                    case 123 {
                        mstore(0x0, 0xb88c914800000000000000000000000000000000000000000000000000000000)
                        mstore(0x4, pair)
                        pop(staticcall(gas(), STRATUM_FACTORY, 0x0, 0x24, 0x0, 0x20))
                        _decimalsOut_xy_fee := mload(0x0)
                    }
                    // cleo stable
                    default {
                        // selector for pairFee(address)
                        mstore(0x0, 0x841fa66b00000000000000000000000000000000000000000000000000000000)
                        mstore(0x4, pair)
                        pop(staticcall(gas(), CLEO_V1_FACTORY, 0x0, 0x24, 0x0, 0x20))
                        // store fee in param
                        _decimalsOut_xy_fee := mload(0x0)
                        // if the fee is zero, it is overridden by the stableFee default
                        if iszero(_decimalsOut_xy_fee) {
                            // selector for stableFee()
                            mstore(0x0, 0x40bbd77500000000000000000000000000000000000000000000000000000000)
                            pop(staticcall(gas(), CLEO_V1_FACTORY, 0x0, 0x24, 0x0, 0x20))
                            _decimalsOut_xy_fee := mload(0x0)
                        }
                    }
                    // calculate and adjust the result (reserveInNew - reserveIn) * 10k / (10k - fee)
                    x := add(
                        div(
                            div(
                                mul(mul(sub(x, _reserveInScaled), _decimalsIn), 10000),
                                sub(10000, _decimalsOut_xy_fee) // 10000 - fee
                            ),
                            SCALE_18
                        ),
                        1 // rounding up
                    )
                }
            }
        }
    }

    /**
     * Executes an exact input swap internally across major UniV2 & Solidly style forks
     * Due to the nature of the V2 impleemntation, the callback is not triggered if no calldata is provided
     * As such, we never enter the callback implementation when using this function
     * @param amountIn sell amount
     * @param useFlashSwap if set to true, the amount in will not be transferred and a
     *                     payback is expected to be done in the callback
     * @return buyAmount output amount
     */
    function swapUniV2ExactInComplete(
        uint256 amountIn,
        uint256 amountOutMin,
        address payer,
        address receiver,
        bool useFlashSwap,
        bytes calldata path
    ) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 22))))
            let tokenIn := calldataload(path.offset)
            let pId_amountWithFee_pathLength := and(shr(80, tokenIn), UINT8_MASK)
            tokenIn := and(ADDRESS_MASK, shr(96, tokenIn))

            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(tokenIn, and(ADDRESS_MASK, shr(96, calldataload(add(path.offset, 42)))))
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch pId_amountWithFee_pathLength
                case 100 {
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
                    let sellReserve
                    switch zeroForOne
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0x0)
                        buyAmount := mload(0x20)
                    }
                    default {
                        sellReserve := mload(0x20)
                        buyAmount := mload(0x0)
                    }
                    // feeAm is 998 for fusionX (1000 - 2) for 0.2% fee
                    pId_amountWithFee_pathLength := mul(amountIn, 998)
                    buyAmount := div(mul(pId_amountWithFee_pathLength, buyAmount), add(pId_amountWithFee_pathLength, mul(sellReserve, 1000)))
                }
                case 101 {
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
                    let sellReserve
                    switch zeroForOne
                    case 1 {
                        // Transpose if pair order is different.
                        sellReserve := mload(0x0)
                        buyAmount := mload(0x20)
                    }
                    default {
                        sellReserve := mload(0x20)
                        buyAmount := mload(0x0)
                    }
                    // feeAm is 997 for Moe (1000 - 3) for 0.3% fee
                    pId_amountWithFee_pathLength := mul(amountIn, 997)
                    buyAmount := div(mul(pId_amountWithFee_pathLength, buyAmount), add(pId_amountWithFee_pathLength, mul(sellReserve, 1000)))
                }
                // all solidly-based protocols (velo, cleo V1, stratum)
                default {
                    // selector for getAmountOut(uint256,address)
                    mstore(ptr, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), amountIn)
                    mstore(add(ptr, 0x24), tokenIn)
                    if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }

                    buyAmount := mload(ptr)
                }

                ////////////////////////////////////////////////////
                // Prepare the swap tx
                ////////////////////////////////////////////////////

                // selector for swap(...)
                mstore(ptr, 0x022c0d9f00000000000000000000000000000000000000000000000000000000)

                switch zeroForOne
                case 0 {
                    mstore(add(ptr, 0x4), buyAmount)
                    mstore(add(ptr, 0x24), 0)
                }
                default {
                    mstore(add(ptr, 0x4), 0)
                    mstore(add(ptr, 0x24), buyAmount)
                }
                mstore(add(ptr, 0x44), receiver)
                mstore(add(ptr, 0x64), 0x80) // bytes offset

                ////////////////////////////////////////////////////
                // In case of a flash swap, we copy the calldata to
                // the execution parameters
                ////////////////////////////////////////////////////
                switch useFlashSwap
                case 1 {
                    // we store the offset of the bytes calldata in the func call
                    let calldataOffsetStart := add(ptr, 0xA4)
                    pId_amountWithFee_pathLength := path.length
                    calldatacopy(calldataOffsetStart, path.offset, pId_amountWithFee_pathLength)
                    // store max amount
                    mstore(add(calldataOffsetStart, pId_amountWithFee_pathLength), shl(128, amountOutMin))
                    // store amountIn
                    mstore(add(calldataOffsetStart, add(pId_amountWithFee_pathLength, 16)), shl(128, amountIn))
                    pId_amountWithFee_pathLength := add(pId_amountWithFee_pathLength, 32)
                    //store amountIn
                    mstore(add(calldataOffsetStart, pId_amountWithFee_pathLength), shl(96, payer))
                    pId_amountWithFee_pathLength := add(pId_amountWithFee_pathLength, 20)
                    // bytes length
                    mstore(add(ptr, 0x84), pId_amountWithFee_pathLength)
                    if iszero(call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        add(0xA4, pId_amountWithFee_pathLength), // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0x0, // output = 0
                        0x0 // output size = 0
                    )) {
                        // Forward the error
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
                ////////////////////////////////////////////////////
                // Otherwise, we have to assume that
                // the swap is prefunded, i.e. the input amount has
                // already been sent to the uniV2 style pool
                ////////////////////////////////////////////////////
                default {
                    ////////////////////////////////////////////////////
                    // We store the bytes length to zero (no callback)
                    // and directly trigger the swap
                    ////////////////////////////////////////////////////
                    mstore(add(ptr, 0x84), 0) // bytes length
                    if iszero(call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )) {
                        // Forward the error
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }

            }
        }
    }
}
