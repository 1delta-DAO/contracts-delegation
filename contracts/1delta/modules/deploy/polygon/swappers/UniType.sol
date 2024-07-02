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
    /// @dev used for some of the denominators in solidly calculations
    uint256 private constant SCALE_18 = 1.0e18;

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
    ) internal {
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
                if xor(address(), receiver) {
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
        uint256 // poolId unused on Polygon for now
    ) internal view returns (uint256 x) {
        assembly {
            let ptr := mload(0x40)
            // Call pair.getReserves(), store the results at `scrap space`
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
                        feeDenom // 
                    )
                ),
                1
            )
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
            let pair := calldataload(add(path.offset, 22))
            // this is expected to be 10000 - x, where x is the poolfee in bps
            let poolFeeDenom := and(shr(80, pair), UINT16_MASK)
            pair := and(ADDRESS_MASK, shr(96, pair))
            // we define this as token in and later re-assign this to
            // reserve in to prevent stack too deep errors
            let tokenIn_reserveIn := calldataload(path.offset)
            tokenIn_reserveIn := and(ADDRESS_MASK, shr(96, tokenIn_reserveIn))

            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(
                    tokenIn_reserveIn,
                    and(ADDRESS_MASK, calldataload(add(path.offset, 30))) // tokenOut
                )
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);

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
                switch zeroForOne
                case 1 {
                    // Transpose if pair order is different.
                    tokenIn_reserveIn := mload(0x0)
                    buyAmount := mload(0x20)
                }
                default {
                    tokenIn_reserveIn := mload(0x20)
                    buyAmount := mload(0x0)
                }
                // feeAm is 997 for Moe (1000 - 3) for 0.3% fee
                poolFeeDenom := mul(amountIn, poolFeeDenom)
                buyAmount := div(mul(poolFeeDenom, buyAmount), add(poolFeeDenom, mul(tokenIn_reserveIn, 1000)))
                

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
                    let pathLength := path.length
                    calldatacopy(calldataOffsetStart, path.offset, pathLength)
                    // store max amount
                    mstore(add(calldataOffsetStart, pathLength), shl(128, amountOutMin))
                    // store amountIn
                    mstore(add(calldataOffsetStart, add(pathLength, 16)), shl(128, amountIn))
                    pathLength := add(pathLength, 32)
                    //store amountIn
                    mstore(add(calldataOffsetStart, pathLength), shl(96, payer))
                    pathLength := add(pathLength, 20)
                    // bytes length
                    mstore(add(ptr, 0x84), pathLength)
                    if iszero(
                        call(
                            gas(),
                            pair,
                            0x0,
                            ptr, // input selector
                            add(0xA4, pathLength), // input size = 164 (selector (4bytes) plus 5*32bytes)
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
    function swapUniV2ExactInFOT(uint256 amountIn, address receiver, bytes calldata path) internal returns (uint256 buyAmount) {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            ////////////////////////////////////////////////////
            // We extract all relevant data from the path bytes blob
            ////////////////////////////////////////////////////
            let pair := calldataload(add(path.offset, 22))
            // this is expected to be 10000 - x, where x is the poolfee in bps
            let poolFeeDenom := and(shr(80, pair), UINT16_MASK)
            pair := and(ADDRESS_MASK, shr(96, pair))
            // we define this as token in and later re-assign this to
            // reserve in to prevent stack too deep errors
            let tokenIn := calldataload(path.offset)
            tokenIn := and(ADDRESS_MASK, shr(96, tokenIn))
            // Compute the buy amount based on the pair reserves.
            {
                let zeroForOne := lt(tokenIn, and(ADDRESS_MASK, calldataload(add(path.offset, 30))))
                // Pairs are in the range (0, 2¹¹²) so this shouldn't overflow.
                // buyAmount = (pairSellAmount * feeAm * buyReserve) /
                //     (pairSellAmount * feeAm + sellReserve * 1000);
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
                // call tokenIn.balanceOf(pair)
                mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
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
                    // returndatacopy(0, 0, returndatasize())
                    // revert(0, returndatasize())
                }
            }
        }
    }
}
