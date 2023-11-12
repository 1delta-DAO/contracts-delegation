// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.23;

import "../../interfaces/IERC20.sol";

/// @dev Helpers for moving tokens around.
abstract contract TokenTransfer {
    // Mask of the lower 20 bytes of a bytes32.
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

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
            mstore(add(ptr, 0x04), and(owner, ADDRESS_MASK))
            mstore(add(ptr, 0x24), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), and(token, ADDRESS_MASK), 0, ptr, 0x64, ptr, 32)

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
            mstore(add(ptr, 0x04), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), and(token, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32)

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
            pop(
                call(
                    21000,
                    recipient,
                    amount,
                    0x0, // input = empty for fallback
                    0x0, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            )
        }
    }

    function _depositWeth(address weth, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer
            // selector for deposit()
            mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
            pop(
                call(
                    gas(),
                    and(weth, ADDRESS_MASK),
                    amount, // ETH to deposit
                    ptr, // seletor for deposit()
                    0x4, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            )
        }
    }

    function _approve(
        address token,
        address to,
        uint256 value
    ) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for approve(address,uint256)
            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), and(to, ADDRESS_MASK))
            mstore(add(ptr, 0x24), value)

            pop(call(gas(), and(token, ADDRESS_MASK), 0, ptr, 0x44, ptr, 32))
        }
    }

    /// @dev Gets the maximum amount of an ERC20 token `token` that can be
    ///      pulled from `owner` by this address.
    /// @param token The token to spend.
    /// @param owner The owner of the tokens.
    /// @return amount The amount of tokens that can be pulled.
    function _getSpendableERC20BalanceOf(address token, address owner) internal view returns (uint256) {
        return min256(IERC20(token).allowance(owner, address(this)), IERC20(token).balanceOf(owner));
    }

    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
