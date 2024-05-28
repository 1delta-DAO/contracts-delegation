// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.26;

/// @dev Helpers for moving tokens around.
abstract contract RawTokenTransfer {
    // Mask of the lower 20 bytes of a bytes32.
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    function _transferERC20TokensFromInternal(bytes calldata data) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), caller())
            mstore(add(ptr, 0x24), shr(96, calldataload(add(data.offset, 20))))
            mstore(add(ptr, 0x44), calldataload(add(data.offset, 40)))

            let success := call(
                gas(),
                and(ADDRESS_MASK, shr(96, calldataload(data.offset))), //
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
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _transferERC20TokensInternal(bytes calldata data) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), shr(96, calldataload(add(data.offset, 20))))
            mstore(add(ptr, 0x24), calldataload(add(data.offset, 40)))

            let success := call(
                gas(),
                and(ADDRESS_MASK, shr(96, calldataload(data.offset))), //
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
                returndatacopy(ptr, 0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    function _transferEthInternal() internal {
        assembly {
            let bal := balance(address())
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
    function _depositNativeInternal(address weth) internal {
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

    function _withdrawNativeInternal(address weth) internal {
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
}
