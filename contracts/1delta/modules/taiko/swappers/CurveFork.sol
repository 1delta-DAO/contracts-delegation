// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

/**
 * @title Curve swapper contract for forks that are very much like curve but with some
 * minor differences
 */
abstract contract CurveForkSwapper {
    // approval slot
    bytes32 private constant CALL_MANAGEMENT_APPROVALS = 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3;

    /// @dev Maximum Uint256 value
    uint256 private constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /** Curve Fork selectors */

    /// @notice selector exchange(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE = 0x5b41b90800000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange_underlying(uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_UNDERLYING = 0x65b2489b00000000000000000000000000000000000000000000000000000000;

    /** Erc20 selectors */

    /// @dev selector for approve(address,uint256)
    bytes32 private constant ERC20_APPROVE = 0x095ea7b300000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transferFrom(address,address,uint256)
    bytes32 private constant ERC20_TRANSFER_FROM = 0x23b872dd00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transfer(address,uint256)
    bytes32 private constant ERC20_TRANSFER = 0xa9059cbb00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for balanceOf(address)
    bytes32 private constant ERC20_BALANCE_OF = 0x70a0823100000000000000000000000000000000000000000000000000000000;

    /**
     * Swaps using a forked curve pool tat forgot to return the output amount
     * tokenIn | actionId | dexId | pool | i | j | sm | tokenOut
     * sm is the selector,
     * i,j are the swap indexes for the pool
     */
    function _swapCurveFork(
        uint256 pathOffset,
        uint256 amountIn,
        address payer,
        address receiver //
    ) internal returns (uint256 amountOut) {
        address token;
        assembly {
            let ptr := mload(0x40)
            token := shr(96, calldataload(pathOffset))
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    token, //
                    0,
                    ptr,
                    0x64,
                    ptr,
                    32
                )

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

            // this one contains [pool | i | j | s | ...]
            let indexData := calldataload(add(pathOffset, 22))
            let pool := shr(96, indexData) // pool is first param

            ////////////////////////////////////////////////////
            // Approve pool if needed
            ////////////////////////////////////////////////////

            // get the approval flag slot first
            mstore(0x0, token) // store tokenIn in scrap
            mstore(0x20, CALL_MANAGEMENT_APPROVALS) // add slot after
            let slot := keccak256(0x0, 0x40)

            // check if approval flag is zero
            if iszero(sload(slot)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), pool)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(
                    call(
                        gas(),
                        token, // tokenIn
                        0,
                        ptr,
                        0x44,
                        ptr,
                        32
                    )
                )
                sstore(slot, 1) // set flag in approval slot
            }

            // we need to get the output amount as these cuve forks

            // might not return amountOut - assign tokenOut to `token`
            token := shr(96, calldataload(add(pathOffset, 45))) // tokenIn, pool + 5x uint8 (i,j,s)
            mstore(0x0, ERC20_BALANCE_OF)
            mstore(0x4, address())
            // call to token
            pop(
                staticcall(
                    gas(),
                    token, // token
                    0x0,
                    0x24,
                    ptr, // output to ptr, we need the stuff at 0x0 later
                    0x20
                )
            )

            amountOut := mload(ptr)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////
            switch and(shr(72, indexData), 0xff) // selectorId
            case 3 {
                // selector for exchange(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) { // no output
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            case 5 {
                // selector for exchange_underlying(uint256,uint256,uint256,uint256)
                mstore(ptr, EXCHANGE_UNDERLYING)
                mstore(add(ptr, 0x4), and(shr(88, indexData), 0xff))
                mstore(add(ptr, 0x24), and(shr(80, indexData), 0xff))
                mstore(add(ptr, 0x44), amountIn)
                mstore(add(ptr, 0x64), 0) // min out is zero, we validate slippage at the end
                if iszero(call(gas(), pool, 0x0, ptr, 0x84, 0x0, 0x0)) { // no output
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                indexData := 0xf
            }
            default {
                revert(0, 0)
            }

            // call to token - note that 0x-0x24 still holds the respective calldata
            pop(
                staticcall(
                    gas(),
                    token, // token
                    0x0,
                    0x24,
                    0x0, // output to ptr
                    0x20
                )
            )
            // load the retrieved balance
            amountOut := sub(mload(0x0), amountOut)

            ////////////////////////////////////////////////////
            // Send funds to receiver if needed
            // indexData is now the flag for manually
            // transferuing to the receiver
            ////////////////////////////////////////////////////
            if and(indexData, xor(receiver, address())) {
                // selector for transfer(address,uint256)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)
                let success := call(
                    gas(),
                    token, // tokenIn, pool + 5x uint8 (i,j,s)
                    0,
                    ptr,
                    0x44,
                    ptr,
                    32
                )

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
    }
}
