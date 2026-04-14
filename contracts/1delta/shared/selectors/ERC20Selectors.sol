// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

abstract contract ERC20Selectors {
    ////////////////////////////////////////////////////
    // ERC20 selectors
    ////////////////////////////////////////////////////

    /// @dev selector for approve(address,uint256)
    bytes32 internal constant ERC20_APPROVE = 0x095ea7b300000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transferFrom(address,address,uint256)
    bytes32 internal constant ERC20_TRANSFER_FROM = 0x23b872dd00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transfer(address,uint256)
    bytes32 internal constant ERC20_TRANSFER = 0xa9059cbb00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for allowance(address,address)
    bytes32 internal constant ERC20_ALLOWANCE = 0xdd62ed3e00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for balanceOf(address)
    bytes32 internal constant ERC20_BALANCE_OF = 0x70a0823100000000000000000000000000000000000000000000000000000000;

    /// @notice Safe ERC20 `transfer` with tolerant success check (boolean or empty return-data).
    /// @dev No-op when `to == address(this)` — callers can unconditionally invoke the helper
    ///      without guarding for the self-transfer case (skip that branch at the call site).
    ///      Reverts forwarding the token's revert data on failure.
    ///      Declared `internal` + asm-only body; stays non-inlined at our optimizer settings
    ///      so multiple call sites share one bytecode copy.
    function _safeTransfer(address token, address to, uint256 amount) internal {
        assembly {
            // Skip the transfer entirely if we're "sending to self"
            if xor(to, address()) {
                let ptr := mload(0x40)
                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), to)
                mstore(add(ptr, 0x24), amount)
                let success := call(gas(), token, 0, ptr, 0x44, 0, 32)
                let rdsize := returndatasize()
                success := and(success, or(iszero(rdsize), and(gt(rdsize, 31), eq(mload(0), 1))))
                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
    }

    /// @notice Safe ERC20 `transferFrom` with tolerant success check.
    /// @dev Unlike `_safeTransfer`, always executes (no self-check) — callers typically move
    ///      tokens from an EOA into the composer, which is almost never the same address.
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), from)
            mstore(add(ptr, 0x24), to)
            mstore(add(ptr, 0x44), amount)
            let success := call(gas(), token, 0, ptr, 0x64, 0, 32)
            let rdsize := returndatasize()
            success := and(success, or(iszero(rdsize), and(gt(rdsize, 31), eq(mload(0), 1))))
            if iszero(success) {
                returndatacopy(0, 0, rdsize)
                revert(0, rdsize)
            }
        }
    }
}
