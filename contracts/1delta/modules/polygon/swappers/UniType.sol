// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

import {V3TypeSwapper} from "./V3Type.sol";

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Uniswap V2 type swapper contract
 * @notice We do everything UniV2 here, incl Solidly, FoT, exactIn and -Out
 */
abstract contract UniTypeSwapper is V3TypeSwapper {
    /// @dev used for some of the denominators in solidly calculations
    uint256 private constant SCALE_18 = 1.0e18;

    ////////////////////////////////////////////////////
    // Uni V2 type selctors
    ////////////////////////////////////////////////////

    /// @dev selector for getReserves()
    bytes32 private constant UNI_V2_GET_RESERVES = 0x0902f1ac00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for swap(...)
    bytes32 private constant UNI_V2_SWAP = 0x022c0d9f00000000000000000000000000000000000000000000000000000000;

    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant QUICK_V2_FF_FACTORY = 0xff5757371414417b8c6caad45baef941abc7d3ab320000000000000000000000;

    bytes32 internal constant UNI_V2_FF_FACTORY = 0xff9e5A52f57b3038F1B8EeE45F28b3C1967e22799C0000000000000000000000;
    bytes32 internal constant CODE_HASH_UNI_V2 = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 internal constant FRAX_SWAP_FF_FACTORY = 0xff54F454D747e037Da288dB568D4121117EAb34e790000000000000000000000;
    bytes32 internal constant CODE_HASH_FRAX_SWAP = 0x4ce0b4ab368f39e4bd03ec712dfc405eb5a36cdb0294b3887b441cd1c743ced3;

    bytes32 internal constant SUSHI_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 internal constant CODE_HASH_SUSHI_V2 = 0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303;

    bytes32 internal constant DFYN_FF_FACTORY = 0xffE7Fb3e833eFE5F9c441105EB65Ef8b261266423B0000000000000000000000;
    bytes32 internal constant CODE_HASH_DFYN = 0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3;

    bytes32 internal constant POLYCAT_FF_FACTORY = 0xff477Ce834Ae6b7aB003cCe4BC4d8697763FF456FA0000000000000000000000;
    bytes32 internal constant CODE_HASH_POLYCAT = 0x3cad6f9e70e13835b4f07e5dd475f25a109450b22811d0437da51e66c161255a;

    bytes32 internal constant APESWAP_FF_FACTORY = 0xffCf083Be4164828f00cAE704EC15a36D7114912840000000000000000000000;
    bytes32 internal constant CODE_HASH_APESWAP = 0x511f0f358fe530cda0859ec20becf391718fdf5a329be02f4c95361f3d6a42d8;

    bytes32 internal constant COMETH_FF_FACTORY = 0xff800b052609c355cA8103E06F022aA30647eAd60a0000000000000000000000;
    bytes32 internal constant CODE_HASH_COMETH = 0x499154cad90a3563f914a25c3710ed01b9a43b8471a35ba8a66a056f37638542;

    bytes32 internal constant WAULTSWAP_FF_FACTORY = 0xffa98ea6356A316b44Bf710D5f9b6b4eA0081409Ef0000000000000000000000;
    bytes32 internal constant CODE_HASH_WAULTSWAP = 0x1cdc2246d318ab84d8bc7ae2a3d81c235f3db4e113f4c6fdc1e2211a9291be47;

    bytes32 internal constant DYSTOPIA_FF_FACTORY = 0xff1d21Db6cde1b18c7E47B0F7F42f4b3F68b9beeC90000000000000000000000;
    bytes32 internal constant CODE_HASH_DYSTOPIA = 0x009bce6d7eb00d3d075e5bd9851068137f44bba159f1cde806a268e20baaf2e8;

    constructor() {}

    /**
     * Swap exact out via v2 type pool
     * Optinally pay in the callback. If ot, we assume that the funds have been prepaid
     * The pay/input amount can be calculated via `getV2AmountInDirect`.
     * @param amountOut receive amount
     * @param maxIn maimum in to pass into callback
     * @param payer payer to pass into callback
     * @param receiver receiver address
     * @param useFlashSwap if true, we assume payment in callback
     */
    function _swapV2StyleExactOut(
        address tokenIn,
        address tokenOut,
        address pair,
        uint256 amountOut,
        uint256 maxIn,
        address payer,
        address receiver,
        bool useFlashSwap,
        uint256 pathOffset,
        uint256 pathLengh
    ) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // selector for swap(...)
            mstore(ptr, UNI_V2_SWAP)

            switch lt(tokenIn, tokenOut)
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
                // Store path
                calldatacopy(add(ptr, 164), pathOffset, pathLengh)

                mstore(add(add(ptr, 164), pathLengh), shl(128, maxIn)) // store amountIn
                pathLengh := add(pathLengh, 32) // pad
                mstore(add(add(ptr, 164), pathLengh), shl(96, payer))
                pathLengh := add(pathLengh, 20)
                /// Store updated data length
                mstore(add(ptr, 132), pathLengh)

                // Perform the external 'swap' call
                if iszero(call(gas(), pair, 0, ptr, add(196, pathLengh), ptr, 0x0)) {
                    // store return value directly to free memory pointer
                    // The call failed; we retrieve the exact error message and revert with it
                    returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                    revert(0, returndatasize()) // Revert with the error message
                }

                ////////////////////////////////////////////////////
                // We chain the transfer to the receiver, given that
                // it is not this address
                ////////////////////////////////////////////////////
                if xor(address(), receiver) {
                    ////////////////////////////////////////////////////
                    // Populate tx for transfer to receiver
                    ////////////////////////////////////////////////////
                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), receiver)
                    mstore(add(ptr, 0x24), amountOut)

                    let success := call(gas(), tokenOut, 0, ptr, 0x44, ptr, 32)

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
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
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
                if iszero(
                    call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
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
     * @param pair provided pair address
     * @param tokenIn input
     * @param tokenOut output
     * @param buyAmount output amunt
     * @return x input amount
     */
    function getV2AmountInDirect(
        address pair,
        address tokenIn, // some DEXs are more efficiently queried directly
        address tokenOut,
        uint256 buyAmount,
        uint256 feeDenom,
        uint256 pId // poolId is used to identify solidly stable
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `scrap space`
            mstore(0x0, UNI_V2_GET_RESERVES)
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
                /// @dev this will be ugly
                default {
                    let _decimalsIn
                    let _decimalsOut_xy_fee
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
                        _decimalsOut_xy_fee := exp(10, mload(0x4))

                        // Call pair.getReserves(), store the results in scrap space
                        mstore(0x0, UNI_V2_GET_RESERVES)
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
                        switch lt(k, _decimalsOut_xy_fee)
                        case 1 {
                            x := add(
                                x,
                                div(
                                    mul(sub(_decimalsOut_xy_fee, k), SCALE_18),
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
                                    mul(sub(k, _decimalsOut_xy_fee), SCALE_18),
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
        uint256 pathOffset,
        uint256 pathLength
    ) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := calldataload(add(pathOffset, 22))
            // this is expected to be 10000 - x, where x is the poolfee in bps
            let poolFeeDenom := and(shr(80, pair), UINT16_MASK)
            pair := shr(96, pair)
            // we define this as token in and later re-assign this to
            // reserve in to prevent stack too deep errors
            let tokenIn_reserveIn := calldataload(pathOffset)

            let pId := and(shr(80, tokenIn_reserveIn), UINT8_MASK)
            tokenIn_reserveIn := shr(96, calldataload(pathOffset))

            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(
                    tokenIn_reserveIn,
                    and(ADDRESS_MASK, calldataload(add(pathOffset, 32))) // tokenOut
                )
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                switch lt(pId, 120)
                case 1 {
                    // Call pair.getReserves(), store the results in scrap space
                    mstore(0x0, UNI_V2_GET_RESERVES)
                    if iszero(staticcall(gas(), pair, 0x0, 0x4, 0x0, 0x40)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    // Revert if the pair contract does not return at least two words.
                    if lt(returndatasize(), 0x40) {
                        revert(0, 0)
                    }
                    switch zeroForOne
                    case 1 {
                        // Transpose if pair order is different.
                        buyAmount := mload(0x20)
                        tokenIn_reserveIn := mload(0x0)
                    }
                    default {
                        tokenIn_reserveIn := mload(0x20)
                        buyAmount := mload(0x0)
                    }
                    poolFeeDenom := mul(amountIn, poolFeeDenom)
                    buyAmount := div(
                        mul(poolFeeDenom, buyAmount),
                        add(poolFeeDenom, mul(tokenIn_reserveIn, 10000)) //
                    )
                }
                // all solidly-based protocols
                default {
                    // selector for getAmountOut(uint256,address)
                    mstore(ptr, 0xf140a35a00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x4), amountIn)
                    mstore(add(ptr, 0x24), tokenIn_reserveIn)
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
                mstore(ptr, UNI_V2_SWAP)

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
                    let _pathLength := pathLength
                    calldatacopy(calldataOffsetStart, pathOffset, _pathLength)
                    // store max amount
                    mstore(add(calldataOffsetStart, _pathLength), shl(128, amountOutMin))
                    // store amountIn
                    mstore(add(calldataOffsetStart, add(_pathLength, 16)), shl(128, amountIn))
                    _pathLength := add(_pathLength, 32)
                    //store amountIn
                    mstore(add(calldataOffsetStart, _pathLength), shl(96, payer))
                    _pathLength := add(_pathLength, 20)
                    // bytes length
                    mstore(add(ptr, 0x84), _pathLength)
                    if iszero(
                        call(
                            gas(),
                            pair,
                            0x0,
                            ptr, // input selector
                            add(0xA4, _pathLength), // input size = 164 (selector (4bytes) plus 5*32bytes)
                            0x0, // output = 0
                            0x0 // output size = 0
                        )
                    ) {
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
                    if iszero(
                        call(
                            gas(),
                            pair,
                            0x0,
                            ptr, // input selector
                            0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                            0, // output = 0
                            0 // output size = 0
                        )
                    ) {
                        // Forward the error
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
            }
        }
    }

    /**
     * Executes an exact input swap internally across major UniV2 forks supporting
     * FOT tokens. Will only be used at the begining of a swap path where users sell a FOT token
     * Due to the nature of the V2 impleemntation, the callback is not triggered if no calldata is provided
     * As such, we never enter the callback implementation when using this function
     * @param amountIn sell amount
     * @return buyAmount output amount
     */
    function swapUniV2ExactInFOT(uint256 amountIn, address receiver, uint256 pathOffset) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := calldataload(add(pathOffset, 22))
            // this is expected to be 10000 - x, where x is the poolfee in bps
            let poolFeeDenom := and(shr(80, pair), UINT16_MASK)
            pair := shr(96, pair)
            // we define this as token in and later re-assign this to
            // reserve in to prevent stack too deep errors
            let tokenIn := shr(96, calldataload(pathOffset))
            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(
                    tokenIn,
                    and(ADDRESS_MASK, calldataload(add(pathOffset, 32))) // tokenOut
                )
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
                // Call pair.getReserves(), store the results in scrap space
                mstore(0x0, UNI_V2_GET_RESERVES)
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
                // call tokenIn.balanceOf(pair)
                mstore(0x0, ERC20_BALANCE_OF)
                mstore(0x4, pair)
                // we store the result
                pop(staticcall(gas(), tokenIn, 0x0, 0x24, 0x0, 0x20))
                amountIn := sub(mload(0x0), sellReserve)

                // adjustment via denominator
                poolFeeDenom := mul(amountIn, poolFeeDenom)
                buyAmount := div(mul(poolFeeDenom, buyAmount), add(poolFeeDenom, mul(sellReserve, 10000)))

                ////////////////////////////////////////////////////
                // Prepare the swap tx
                ////////////////////////////////////////////////////

                // selector for swap(...)
                mstore(ptr, UNI_V2_SWAP)

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
                // We store the bytes length to zero (no callback)
                // and directly trigger the swap
                ////////////////////////////////////////////////////
                mstore(add(ptr, 0x84), 0) // bytes length
                if iszero(
                    call(
                        gas(),
                        pair,
                        0x0,
                        ptr, // input selector
                        0xA4, // input size = 164 (selector (4bytes) plus 5*32bytes)
                        0, // output = 0
                        0 // output size = 0
                    )
                ) {
                    // Forward the error
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }
        }
    }
}
