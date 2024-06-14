// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.26;

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

    // deposit native by just sending native to it
    function _depositNative(address weth) internal {
        assembly {
            if iszero(
                call(
                    gas(),
                    weth,
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

    function _withdrawNative(address weth) internal {
        assembly {
            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(add(0x0, 0x4), address())

            // call to underlying
            pop(staticcall(gas(), weth, 0x0, 0x24, 0x0, 0x20))

            let thisBalance := mload(0x0)

            // selector for withdraw(uint256)
            mstore(0x0, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
            mstore(0x4, thisBalance)
            if iszero(
                call(
                    gas(),
                    weth,
                    0x0, // no ETH
                    0x0, // seletor for deposit()
                    0x24, // input size = zero
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                revert(0, 0) // revert when native transfer fails
            }
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
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), value)

            pop(call(gas(), token, 0, ptr, 0x44, ptr, 32))
        }
    }

    // balanceOf call in assembly for smaller contract size
    function _balanceOf(address underlying, address entity) internal view returns (uint256 entityBalance) {
        assembly {
            ////////////////////////////////////////////////////
            // get token balance in assembly usingn scrap space (64 bytes)
            ////////////////////////////////////////////////////

            // selector for balanceOf(address)
            mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            // add this address as parameter
            mstore(0x4, entity)
            // call to underlying
            let success := staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)
            // revert if no success or returndatasize is less than 32 bytes
            if or(iszero(success), lt(returndatasize(), 0x20)) {
                revert(0, 0)
            }
            // load entity balance
            entityBalance := mload(0x0)
        }
    }
}
