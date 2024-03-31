// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

/// @dev Helpers for moving tokens around.
abstract contract TokenTransfer {
    /// @dev Transfers ERC20 tokens from `owner` to `to`.
    /// @param token The token to spend.
    /// @param owner The owner of the tokens.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20TokensFrom(
        address token,
        address owner,
        address to,
        uint256 amount
    ) internal {
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
    function _transferERC20Tokens(
        address token,
        address to,
        uint256 amount
    ) internal {
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

    function _transferEth(address recipient, uint256 amount) internal {
        assembly {
            if iszero(
                call(
                    gas(),
                    recipient,
                    amount,
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

    function _depositNative(address weth, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            // selector for deposit()
            mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
            if iszero(
                call(
                    gas(),
                    weth,
                    amount, // ETH to deposit
                    ptr, // seletor for deposit()
                    0x4, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                revert(0, 0) // revert when native transfer fails
            }
        }
    }

    function _withdrawNative(address weth, uint256 amount) internal {
        assembly {
            // selector for withdraw(uint256)
            mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
            mstore(0x4, amount)
            if iszero(
                call(
                    gas(),
                    weth,
                    0x0, // no ETH
                    0x0, // seletor for deposit()
                    0x24, // input size = selector plus amount
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                revert(0, 0) // revert when native transfer fails
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

    /// @dev Gets the maximum amount of an ERC20 token `token` that can be
    ///      pulled from `owner` by this address.
    /// @param token The token to spend.
    /// @param owner The owner of the tokens.
    /// @return spendableBalance The amount of tokens that can be pulled.
    function _getSpendableERC20BalanceOf(address token, address owner) internal view returns (uint256 spendableBalance) {
        // return min256(IERC20(token).allowance(owner, address(this)), IERC20(token).balanceOf(owner));
        assembly {
            let ptr := mload(0x40)
            // balanceOf
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), owner)
            // call to token
            let success := staticcall(gas(), token, ptr, 0x24, ptr, 0x20)
            // success is false or return data not provided
            if or(iszero(success), lt(returndatasize(), 0x20)) {
                revert(0, 0)
            }
            // load balance
            let tokenBalance := mload(ptr)
            // allowance
            mstore(ptr, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), owner)
            mstore(add(ptr, 0x24), address())
            // call to token
            success := staticcall(gas(), token, ptr, 0x44, ptr, 0x20)
            // success is false or return data not provided
            if or(iszero(success), lt(returndatasize(), 0x20)) {
                revert(0, 0)
            }
            // load allowance
            let allowed := mload(ptr)
            switch gt(tokenBalance, allowed)
            case 0 {
                spendableBalance := tokenBalance
            }
            default {
                spendableBalance := allowed
            }
        }
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256 minimum) {
        return a < b ? a : b;
    }
}
