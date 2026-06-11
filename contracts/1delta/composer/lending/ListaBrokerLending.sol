// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

/**
 * @notice Borrow/repay against a Lista fixed-term `LendingBroker` (Moolah-backed market).
 * @dev The broker is the registered market broker in Moolah and the mandatory gateway for the
 *      debt side of these markets — collateral supply/withdraw still go through the normal
 *      Moolah/Morpho path (`MorphoLending`). The broker call shape carries no `MarketParams`
 *      (the broker resolves its own market), so these ops use a lean, purpose-built layout.
 *
 *      The position owner (`user` on borrow, `onBehalf` on repay) is ALWAYS the authenticated
 *      composer caller — never calldata-injected — so a position can only be acted on by its owner.
 */
abstract contract ListaBrokerLending is ERC20Selectors, Masks {
    /// @dev `borrow(uint256 amount,uint256 termId,address user,address receiver)`
    bytes32 private constant LISTA_BROKER_BORROW = 0x3d5d4a9e00000000000000000000000000000000000000000000000000000000;

    /// @dev `repay(uint256 amount,uint256 posId,address onBehalf)` (fixed position)
    bytes32 private constant LISTA_BROKER_REPAY_FIXED = 0xb1e8f8ef00000000000000000000000000000000000000000000000000000000;

    /// @dev `repay(uint256 amount,address onBehalf)` (dynamic position)
    bytes32 private constant LISTA_BROKER_REPAY_DYNAMIC = 0xacb7081500000000000000000000000000000000000000000000000000000000;

    /// @dev posId sentinel selecting the user's dynamic (flexible) position on repay
    uint256 private constant DYNAMIC_POS_ID = 0xffffffffffffffffffffffffffffffff;

    /**
     * @notice Borrows from a Lista fixed-term `LendingBroker`.
     * @dev Calls `borrow(amount, termId, user, receiver)`. The broker borrows from Moolah on
     *      behalf of `user` (= the authenticated caller, who must have authorized this composer in
     *      Moolah) and forwards the ERC20 loan token to `receiver`. Amount is an explicit assets
     *      amount (no shares, no balance read).
     * @param currentOffset Current position in the calldata
     * @param callerAddress Authenticated caller; becomes the broker position owner `user`
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 16             | flags + Amount (borrowAm)       |
     * | 16     | 20             | broker                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 16             | termId                          |
     */
    function _listaBrokerBorrow(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)

            // borrow(uint256 amount, uint256 termId, address user, address receiver)
            mstore(ptr, LISTA_BROKER_BORROW)
            // amount (assets only, lower 14 bytes of the 16-byte amount word)
            mstore(add(ptr, 4), and(UINT112_MASK, shr(128, calldataload(currentOffset))))
            // termId (16 bytes at offset 56)
            mstore(add(ptr, 36), shr(128, calldataload(add(currentOffset, 56))))
            // user (broker position owner) is the authenticated caller
            mstore(add(ptr, 68), and(ADDRESS_MASK, callerAddress))
            // receiver of the borrowed tokens
            mstore(add(ptr, 100), shr(96, calldataload(add(currentOffset, 36))))

            let broker := shr(96, calldataload(add(currentOffset, 16)))

            currentOffset := add(currentOffset, 72)

            if iszero(
                call(
                    gas(),
                    broker,
                    0x0,
                    ptr,
                    132, // = 4 + 4 * 32
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }

    /**
     * @notice Repays a Lista fixed-term `LendingBroker` position.
     * @dev The broker pulls the loan token from this composer (`msg.sender`) via `transferFrom`
     *      (composer must approve the broker) or accepts native BNB via `msg.value`, repays
     *      interest-first (plus an early-repayment penalty for fixed positions) and refunds any
     *      excess back to the composer. `amount == 0` repays the composer's full balance.
     *      `posId == type(uint128).max` selects the dynamic position; any other value targets that
     *      specific fixed position.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Authenticated caller; the position owner whose debt is repaid (`onBehalf`)
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | loanToken                       |
     * | 20     | 16             | flags + Amount                  |
     * | 36     | 20             | broker                          |
     * | 56     | 16             | posId (max == dynamic position) |
     */
    function _listaBrokerRepay(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)

            let token := shr(96, calldataload(currentOffset)) // loanToken
            let amountWord := shr(128, calldataload(add(currentOffset, 20))) // 16-byte flags + amount
            let repayAm := and(UINT112_MASK, amountWord)
            let isNative := and(NATIVE_FLAG, amountWord)
            let broker := shr(96, calldataload(add(currentOffset, 36)))
            let posId := shr(128, calldataload(add(currentOffset, 56)))
            // onBehalf is the authenticated caller, never calldata-injected
            let onBehalf := and(ADDRESS_MASK, callerAddress)

            /**
             * if amount is 0 -> repay the composer balance (ERC20 or native).
             * Otherwise repay the explicit amount. The broker refunds any excess to the composer.
             */
            switch isNative
            case 0 {
                if iszero(repayAm) {
                    mstore(0x0, ERC20_BALANCE_OF)
                    mstore(0x04, address())
                    if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) { revert(0x0, 0x0) }
                    repayAm := mload(0x0)
                }
            }
            default {
                if iszero(repayAm) { repayAm := selfbalance() }
            }

            // native: forward repayAm as call value; ERC20: call value is 0
            let callValue := mul(repayAm, iszero(iszero(isNative)))

            let callLength
            switch eq(posId, DYNAMIC_POS_ID)
            case 1 {
                // repay(uint256 amount, address onBehalf) — dynamic position
                mstore(ptr, LISTA_BROKER_REPAY_DYNAMIC)
                mstore(add(ptr, 4), repayAm)
                mstore(add(ptr, 36), onBehalf)
                callLength := 68 // = 4 + 2 * 32
            }
            default {
                // repay(uint256 amount, uint256 posId, address onBehalf) — fixed position
                mstore(ptr, LISTA_BROKER_REPAY_FIXED)
                mstore(add(ptr, 4), repayAm)
                mstore(add(ptr, 36), posId)
                mstore(add(ptr, 68), onBehalf)
                callLength := 100 // = 4 + 3 * 32
            }

            currentOffset := add(currentOffset, 72)

            if iszero(call(gas(), broker, callValue, ptr, callLength, 0x0, 0x0)) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }
        }
        return currentOffset;
    }
}
