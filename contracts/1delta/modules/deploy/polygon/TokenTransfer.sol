// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.26;

import {PermitUtils} from "./permit/PermitUtils.sol";

/// @dev Helpers for moving tokens around.
abstract contract TokenTransfer is PermitUtils {
    address internal constant WRAPPED_NATIVE = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    /// @dev Transfers ERC20 tokens from `owner` to `to`.
    /// @param token The token to spend.
    /// @param owner The owner of the tokens.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20TokensFrom(address token, address owner, address to, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), owner)
            mstore(add(ptr, 0x24), to)
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), token, 0, ptr, 0x64, ptr, 32)

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
    }

    /// @dev Transfers ERC20 tokens from ourselves to `to`.
    /// @param token The token to spend.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20Tokens(address token, address to, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), token, 0, ptr, 0x44, ptr, 32)

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
    }

    /** NATIVE TRANSFERS  */

    function _transferEth() internal {
        assembly {
            let bal := selfbalance()
            if not(iszero(bal)) {
                if iszero(
                    call(
                        gas(),
                        caller(),
                        bal,
                        0x0, // input = empty for fallback
                        0x0, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    revert(0, 0) // revert when native transfer fails
                }
            }
        }
    }

    function _transferEthTo(address recipient) internal {
        assembly {
            let bal := selfbalance()
            if not(iszero(bal)) {
                if iszero(
                    call(
                        gas(),
                        recipient,
                        bal,
                        0x0, // input = empty for fallback
                        0x0, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    revert(0, 0) // revert when native transfer fails
                }
            }
        }
    }

    // deposit native by just sending native to it
    function _depositNativeAmount(uint256 amount) internal {
        assembly {
            if iszero(
                call(
                    gas(),
                    WRAPPED_NATIVE,
                    amount, // ETH to deposit
                    0x0, // no input
                    0x0, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                revert(0, 0) // revert when native transfer fails
            }
        }
    }

        // deposit native by just sending native to it
    function _depositNative() internal {
        assembly {
            if iszero(
                call(
                    gas(),
                    WRAPPED_NATIVE,
                    callvalue(), // ETH to deposit
                    0x0, // no input
                    0x0, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                revert(0, 0) // revert when native transfer fails
            }
        }
    }

    // deposit native by just sending native to it
    function _depositNativeTo(address receiver) internal {
        assembly {
            let amount := callvalue()

            let success := call(
                gas(),
                WRAPPED_NATIVE,
                callvalue(), // ETH to deposit
                0x0, // no input
                0x0, // input size = zero
                0x0, // output = empty
                0x0 // output size = zero
            )
            if iszero(success) {
                revert(0, 0) // revert when native transfer fails
            }

            let ptr := mload(0x40) // free memory pointer

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), amount)

            success := call(gas(), WRAPPED_NATIVE, 0, ptr, 0x44, ptr, 32)

            let rdsize := returndatasize()

            // Abbreviated check for standard WETH implementation
            success := and(
                success, // call itself succeeded
                eq(mload(ptr), 1) // starts with uint256(1)
            )

            if iszero(success) {
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _withdrawWrappedNativeTo(address payable receiver) internal {
        assembly {
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(0x0, 0x4), address())

            // call to underlying
            pop(staticcall(gas(), WRAPPED_NATIVE, 0x0, 0x24, 0x0, 0x20))

            let thisBalance := mload(0x0)

            // only do something if balance is positive
            if gt(thisBalance, 0x0) {
                // selector for withdraw(uint256)
                mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(0x4, thisBalance)
                // should not fail since WRAPPED_NATIVE is immutable
                pop(
                    call(
                        gas(),
                        WRAPPED_NATIVE,
                        0x0, // no ETH
                        0x0, // start of data
                        0x24, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                )

                // transfer native to receiver
                if iszero(
                    call(
                        gas(),
                        receiver,
                        thisBalance,
                        0x0, // input = empty for fallback
                        0x0, // input size = zero
                        0x0, // output = empty
                        0x0 // output size = zero
                    )
                ) {
                    // should only revert if receiver cannot receive native
                    revert(0, 0)
                }
            }
        }
    }

    function _approve(address token, address to, uint256 value) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for approve(address,uint256)
            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), value)

            pop(call(gas(), token, 0, ptr, 0x44, ptr, 32))
        }
    }
}
