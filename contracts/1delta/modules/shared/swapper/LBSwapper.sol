// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

// solhint-disable max-line-length

/**
 * @title LB swapper contract
 */
abstract contract LBSwapper {
    /**
     * Executes a swap on merchant Moe's LB exact in
     * The pair address is fetched from the factory
     * @param tokenOut output
     * @param pair pair address
     * @param receiver receiver address
     * @return amountOut buy amount
     */
    function swapLBexactIn(
        address tokenOut,
        address pair,
        address receiver //
    )
        internal
        returns (uint256 amountOut)
    {
        assembly {
            // getTokenY()
            mstore(0x0, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    0x0,
                    0x4, // selector only
                    0x0,
                    0x20
                )
            ) { revert(0, 0) }
            let swapForY := eq(tokenOut, mload(0x0))
            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            let ptr := mload(0x40)
            // swap(bool,address)
            mstore(ptr, 0x53c059a000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), swapForY)
            mstore(add(ptr, 0x24), receiver)
            // call swap, revert if invalid/undefined pair
            if iszero(call(gas(), pair, 0x0, ptr, 0x44, ptr, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 { amountOut := and(mload(ptr), 0xffffffffffffffffffffffffffffffff) }
            default { amountOut := shr(128, mload(ptr)) }
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
        address receiver //
    )
        internal
    {
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
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            ////////////////////////////////////////////////////
            // Validate amount received
            ////////////////////////////////////////////////////

            // we fetch the amount out we actually got
            let amountOutReceived
            // the swap call returns both amounts encoded into a single bytes32 as (amountX,amountY)
            switch swapForY
            case 0 { amountOutReceived := and(mload(ptr), 0xffffffffffffffffffffffffffffffff) }
            default { amountOutReceived := shr(128, mload(ptr)) }
            // revert if we did not get enough
            if lt(amountOutReceived, amountOut) { revert(0, 0) }
        }
    }

    /**
     * Calculates Merchant Moe's LB amount in
     * @param tokenOut output
     * @param amountOut buy amount
     * @return amountIn buy amount
     * @return swapForY flag for tokenOut = tokenY
     */
    function getLBAmountIn(
        address tokenOut,
        address pair,
        uint256 amountOut //
    )
        internal
        view
        returns (uint256 amountIn, bool swapForY)
    {
        assembly {
            // getTokenY()
            mstore(0x0, 0xda10610c00000000000000000000000000000000000000000000000000000000)
            if iszero(
                // the call will always succeed due to the pair being nonzero
                staticcall(
                    gas(),
                    pair,
                    0x0,
                    0x4, // selector only
                    0x0,
                    0x20
                )
            ) { revert(0, 0) }
            // override swapForY
            swapForY := eq(tokenOut, mload(0x0))

            let ptr := mload(0x40)
            // getSwapIn(uint128,bool)
            mstore(ptr, 0xabcd783000000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), amountOut)
            mstore(add(ptr, 0x24), swapForY)
            // call swap simulator, revert if invalid/undefined pair
            if iszero(staticcall(gas(), pair, ptr, 0x44, ptr, 0x40)) { revert(0, 0) }
            amountIn :=
                and(
                    0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff, // mask uint128
                    mload(ptr)
                )
            // the second slot returns amount out left, if positive, we revert
            if gt(0, mload(add(ptr, 0x20))) { revert(0, 0) }
        }
    }
}
