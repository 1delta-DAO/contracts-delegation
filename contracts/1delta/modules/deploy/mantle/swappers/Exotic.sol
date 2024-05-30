// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract ExoticSwapper {

    address internal constant MERCHANT_MOE_LB_FACTORY = 0xa6630671775c4EA2743840F9A5016dCf2A104054;

    address private constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;
    address internal constant REBATE_RECIPIENT = 0xC95eED7F6E8334611765F84CEb8ED6270F08907E;

    address internal constant KTX_VAULT = 0x2e488D7ED78171793FA91fAd5352Be423A50Dae1;
    address internal constant KTX_VAULT_UTILS = 0x25e71a6b45598213E95F9a718e3FE0523e9d9E34;
    address internal constant KTX_VAULT_PRICE_FEED = 0xEdd1E8aACF7652aD8c015C4A403A9aE36F3Fe4B7;

    constructor() {}

    /**
     * Swaps exact input on WOOFi DEX
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapWooFiExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address payer, // funds can be pulled directly from a user
        address receiver
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let success
            switch eq(payer, address())
            case 0 {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), WOO_POOL)
                mstore(add(ptr, 0x44), amountIn)

                success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            default {
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), WOO_POOL)
                mstore(add(ptr, 0x24), amountIn)

                success := call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            // selector for swap(address,address,uint256,uint256,address,address)
            mstore(
                ptr, // 2816
                0x7dc2038200000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)
            mstore(add(ptr, 0x44), amountIn)
            mstore(add(ptr, 0x64), 0x0) // amountOutMin unused
            mstore(add(ptr, 0x84), receiver) // recipient
            mstore(add(ptr, 0xA4), REBATE_RECIPIENT) // rebateTo
            success := call(
                gas(),
                WOO_POOL,
                0x0, // no native transfer
                ptr,
                0xC4, // input length 196
                ptr, // store output here
                0x20 // output is just uint
            )
            if iszero(success) {
                let rdsize := returndatasize()
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Swaps exact input on KTX spot DEX
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapKTXExactIn(
        address tokenIn, 
        address tokenOut, 
        uint256 amountIn, 
        address receiver,
        address payer
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)
            let success
            switch eq(payer, address())
            case 0 {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), KTX_VAULT)
                mstore(add(ptr, 0x44), amountIn)

                success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            default {
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), KTX_VAULT)
                mstore(add(ptr, 0x24), amountIn)
                success := call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }

            // selector for swap(address,address,address)
            mstore(
                ptr, // 2816
                0x9331621200000000000000000000000000000000000000000000000000000000
            )
            mstore(add(ptr, 0x04), tokenIn)
            mstore(add(ptr, 0x24), tokenOut)
            mstore(add(ptr, 0x44), receiver)
            success := call(
                gas(),
                KTX_VAULT,
                0x0, // no native transfer
                ptr,
                0x64, // input length 66 bytes
                ptr, // store output here
                0x20 // output is just uint
            )
            if iszero(success) {
                let rdsize := returndatasize()
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }

            amountOut := mload(ptr)
        }
    }

    /**
     * Executes a swap on merchant Moe's LB exact in
     * The pair address is fetched from the factory
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @param receiver receiver address
     * @param binStep bin indetifier
     * @return amountOut buy amount
     */
    function swapLBexactIn(
        address tokenIn, 
        address tokenOut, 
        uint256 amountIn,
        address payer,
        address receiver,
        uint16 binStep // identifies pair
    ) internal returns (uint256 amountOut) {
        assembly {
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // Get the pair adress from the factory
            ////////////////////////////////////////////////////

            // getLBPairInformation(address,address,uint256)
            mstore(ptr, 0x704037bd00000000000000000000000000000000000000000000000000000000)
            // this flag indicates whether tokenOut is tokenY
            // the tokens in the pair are ordered, as such, we call lt
            let swapForY := lt(tokenIn, tokenOut)
            // order tokens for call
            switch swapForY
            case 1 {
                mstore(add(ptr, 0x4), tokenIn)
                mstore(add(ptr, 0x24), tokenOut)
            }
            default {
                mstore(add(ptr, 0x4), tokenOut)
                mstore(add(ptr, 0x24), tokenIn)
            }
            mstore(add(ptr, 0x44), binStep)
            pop( // the call will always succeed due to immutable call target
                staticcall(
                    gas(),
                    MERCHANT_MOE_LB_FACTORY,
                    ptr,
                    0x64,
                    ptr,
                    0x40 // we only need 64 bits of the output
                )
            )
            // get the pair
            let pair := and(
                0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff, // mask address
                mload(add(ptr, 0x20)) // skip index
            )
            // pair must exist
            if iszero(pair) {
                revert(0, 0)
            }
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    ptr,
                    0x4,
                    ptr,
                    0x20
                )
            )
            swapForY := eq(tokenOut, mload(ptr)) 
            ////////////////////////////////////////////////////
            // Transfer amountIn to pair
            ////////////////////////////////////////////////////
            switch eq(payer, address())
            case 0 {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), pair)
                mstore(add(ptr, 0x44), amountIn)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            } 
            default {
                // selector for transfer(address,uint256)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), pair)
                mstore(add(ptr, 0x24), amountIn)

                let success := call(gas(), tokenIn, 0x0, ptr, 0x44, ptr, 32)

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
                    returndatacopy(ptr, 0, rdsize)
                    revert(ptr, rdsize)
                }
            }
            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                let rdsize := returndatasize()
                revert(ptr, rdsize)
            }
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 {
                amountOut := and(mload(ptr), 0xffffffffffffffffffffffffffffffff)
            }
            default {
                amountOut := shr(128, mload(ptr))
            }
        }
    }

    /**
     * Swaps Merchant Moe's LB exact output internally
     * @param pair address provided byt the factory
     * @param swapForY flag for tokenY being the output token
     * @param amountOut amountOut used to validate that we received enough
     * @param receiver receiver address
     */
    function swapLBexactOut(
        address pair,
        bool swapForY, 
        uint256 amountOut, 
        address receiver
    ) internal {
        assembly {
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                revert(ptr, returndatasize())
            }

            ////////////////////////////////////////////////////
            // Validate amount received
            ////////////////////////////////////////////////////

            // we fetch the amount out we actually got
            let amountOutReceived
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 {
                amountOutReceived := and(mload(ptr), 0xffffffffffffffffffffffffffffffff)
            }
            default {
                amountOutReceived := shr(128, mload(ptr))
            }
            // revert if we did not get enough
            if lt(amountOutReceived, amountOut) {
                revert (0, 0)
            }
        }    
    }

    /**
     * Calculates Merchant Moe's LB amount in
     * @param tokenIn input
     * @param tokenOut output
     * @param amountOut buy amount
     * @param binStep bin identifier
     * @return amountIn buy amount
     * @return pair pair address
     * @return swapForY flag for tokenOut = tokenY
     */
    function getLBAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint16 binStep // this param identifies the pair
    ) internal view returns (uint256 amountIn, address pair, bool swapForY) {
        assembly {
            let ptr := mload(0x40)
            // getLBPairInformation(address,address,uint256)
            mstore(ptr, 0x704037bd00000000000000000000000000000000000000000000000000000000)
            // this flag indicates whether tokenOut is tokenY
            // the tokens in the pair are ordered, as such, we call lt
            swapForY := lt(tokenIn, tokenOut)
            // order tokens for call
            switch swapForY
            case 1 {
                mstore(add(ptr, 0x4), tokenIn)
                mstore(add(ptr, 0x24), tokenOut)
            }
            default {
                mstore(add(ptr, 0x4), tokenOut)
                mstore(add(ptr, 0x24), tokenIn)
            }
            mstore(add(ptr, 0x44), binStep)
            pop(
                // the call will always succeed due to immutable call target
                staticcall(
                    gas(),
                    MERCHANT_MOE_LB_FACTORY,
                    ptr,
                    0x64,
                    ptr,
                    0x40 // we only need 64 bits of the output
                )
            )
            // get the pair
            pair := and(
                0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff, // mask address
                mload(add(ptr, 0x20)) // skip index
            )
            // pair must exist
            if iszero(pair) {
                revert(0, 0)
            }
            // getTokenY()
            mstore(ptr, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            pop(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    ptr,
                    0x4,
                    ptr,
                    0x20
                )
            )
            // override swapForY
            swapForY := eq(tokenOut, mload(ptr)) 
            // getSwapIn(uint128,bool)
            mstore(ptr, 0xabcd783000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountOut)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) {
                revert(0, 0)
            }
            amountIn := and(
                0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                mload(ptr)
            )
            // the second slot returns amount out left, if positive, we revert
            if gt(0, mload(add(ptr, 0x20))) {
                revert(0, 0)
            }
        }
    }
}
