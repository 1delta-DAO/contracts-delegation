// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Morpho Midnight.
 *
 * @dev Midnight is a fixed-rate, fixed-maturity, order-book lending primitive - NOT a Morpho Blue
 * fork. There is no pool `supply`/`borrow`: lending and borrowing both happen through `take`, which
 * consumes an off-chain-signed maker `Offer` (lend = buy zero-coupon credit units, borrow = sell debt
 * units). Position lifecycle is handled by `supplyCollateral` / `withdrawCollateral` / `repay` /
 * `withdraw` (credit redemption).
 *
 * Because every Midnight entry-point takes the full `Market` struct (which embeds a dynamic
 * `CollateralParams[]` array) - and offers/ratifier data originate off-chain - we do NOT hand-pack the
 * arguments like the Blue integration. Instead the caller supplies the ABI-encoded argument tuple
 * (everything after the selector) and this module:
 *   1. writes the selector itself (so the op is bound to a specific Midnight function and the caller
 *      cannot swap in a different one that would shift which head word is the authorization field), and
 *   2. on the allowance-spending OUTFLOWS (`withdrawCollateral` / `withdraw` / borrow-side `take`)
 *      overwrites the authorization-critical head word (`onBehalf` / `taker`) with `callerAddress`, so a
 *      caller can only ever withdraw/borrow against their OWN position. Benign inflows
 *      (`supplyCollateral` / `repay`) leave `onBehalf` caller-parameterized — crediting collateral to,
 *      or repaying the debt of, any position is harmless (matching the Morpho Blue supply/repay
 *      convention).
 *
 * The caller must ensure the composer is authorized on Midnight (`setIsAuthorized`) and, for the paying
 * paths (supplyCollateral / repay / lending-side take), has approved Midnight for the relevant token
 * (via a separate APPROVE transfer op in the same batch).
 */
abstract contract MidnightLending is ERC20Selectors, Masks {
    /// @dev supplyCollateral((uint256,address,address,(address,uint256,uint256,address)[],uint256,uint256,address,address),uint256,uint256,address)
    bytes32 private constant MIDNIGHT_SUPPLY_COLLATERAL = 0x32292d9600000000000000000000000000000000000000000000000000000000;

    /// @dev withdrawCollateral(Market,uint256,uint256,address,address)
    bytes32 private constant MIDNIGHT_WITHDRAW_COLLATERAL = 0xa121e2a900000000000000000000000000000000000000000000000000000000;

    /// @dev repay(Market,uint256,address,address,bytes)
    bytes32 private constant MIDNIGHT_REPAY = 0x6b210f9e00000000000000000000000000000000000000000000000000000000;

    /// @dev withdraw(Market,uint256,address,address)
    bytes32 private constant MIDNIGHT_WITHDRAW = 0xa6db175000000000000000000000000000000000000000000000000000000000;

    /// @dev take(Offer,bytes,uint256,address,address,address,bytes)
    bytes32 private constant MIDNIGHT_TAKE = 0x6a14c9ef00000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Supplies collateral to a Morpho Midnight market (`supplyCollateral`).
     * @dev `onBehalf` (head word 3) is taken as-is from the caller-encoded args: supply is a benign
     *      inflow (it can only credit collateral to a position), so it may target any address — matching
     *      the Morpho Blue supply convention. Only the allowance-spending outflows (withdrawCollateral /
     *      withdraw / borrow-side take) pin the owner to `callerAddress`. The `assets` amount (head word 2)
     *      is injected at runtime: a zero amount resolves to this contract's balance of `collateralToken`.
     *      The pull is `transferFrom(msg.sender=composer, ...)`, so the composer must hold + have approved
     *      the collateral (approval handled by a separate compose op).
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                              |
     * |--------|----------------|----------------------------------------------------------|
     * | 0      | 20             | midnight (target)                                        |
     * | 20     | 20             | collateralToken (for zero-amount balance resolution)     |
     * | 40     | 16             | assets (0 => contract balance of collateralToken)        |
     * | 56     | 2              | argsLength                                               |
     * | 58     | argsLength     | ABI-encoded args (Market, collateralIndex, assets, onBehalf) |
     */
    function _midnightSupplyCollateral(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))
            let token := shr(96, calldataload(add(currentOffset, 20)))
            let amount := shr(128, calldataload(add(currentOffset, 40)))
            let argsLength := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 56))))
            let argsOffset := add(currentOffset, 58)

            // zero amount => use the full contract balance of the collateral token
            if iszero(amount) {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)
            mstore(ptr, MIDNIGHT_SUPPLY_COLLATERAL)
            calldatacopy(add(ptr, 4), argsOffset, argsLength)
            // inject assets (word 2); onBehalf (word 3) is left as the caller encoded it (benign inflow)
            mstore(add(ptr, 68), amount) // assets

            if iszero(call(gas(), target, 0x0, ptr, add(4, argsLength), 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(argsOffset, argsLength)
        }
        return currentOffset;
    }

    /**
     * @notice Withdraws collateral from a Morpho Midnight market (`withdrawCollateral`).
     * @dev `onBehalf` (head word 3) is pinned to `callerAddress`. The `receiver` (head word 4) and
     *      `assets` (head word 2) are taken as-is from the caller-encoded args (the caller may route the
     *      collateral to the composer to continue the batch, or to themselves).
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                                       |
     * |--------|----------------|-------------------------------------------------------------------|
     * | 0      | 20             | midnight (target)                                                 |
     * | 20     | 2              | argsLength                                                        |
     * | 22     | argsLength     | ABI-encoded args (Market, collateralIndex, assets, onBehalf, receiver) |
     */
    function _midnightWithdrawCollateral(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))
            let argsLength := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 20))))
            let argsOffset := add(currentOffset, 22)

            let ptr := mload(0x40)
            mstore(ptr, MIDNIGHT_WITHDRAW_COLLATERAL)
            calldatacopy(add(ptr, 4), argsOffset, argsLength)
            // pin onBehalf (word 3)
            mstore(add(ptr, 100), callerAddress)

            if iszero(call(gas(), target, 0x0, ptr, add(4, argsLength), 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(argsOffset, argsLength)
        }
        return currentOffset;
    }

    /**
     * @notice Repays debt units to a Morpho Midnight market (`repay`).
     * @dev `onBehalf` (head word 2) is NOT pinned - it is the caller-encoded address whose debt is repaid.
     *      Unlike the outflow ops, repay is a pure inflow (the composer pays and someone's debt shrinks), so
     *      repaying on behalf of any address is benign - matching the Blue/Aave repay convention. `callback`
     *      (head word 3) is forced to zero, so Midnight pulls the loan token from `msg.sender` (the composer)
     *      and never invokes a caller-supplied repay callback. `units` (head word 1) is injected: a zero
     *      amount resolves to the contract balance of `loanToken` (1 unit == 1 loan token at repayment). The
     *      caller must ensure the resolved amount does not exceed the position debt (Midnight reverts on
     *      over-repay).
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                              |
     * |--------|----------------|----------------------------------------------------------|
     * | 0      | 20             | midnight (target)                                        |
     * | 20     | 20             | loanToken (for zero-amount balance resolution)           |
     * | 40     | 16             | units (0 => contract balance of loanToken)               |
     * | 56     | 2              | argsLength                                               |
     * | 58     | argsLength     | ABI-encoded args (Market, units, onBehalf, callback, data) |
     */
    function _midnightRepay(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))
            let token := shr(96, calldataload(add(currentOffset, 20)))
            let amount := shr(128, calldataload(add(currentOffset, 40)))
            let argsLength := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 56))))
            let argsOffset := add(currentOffset, 58)

            // zero amount => repay the full contract balance of the loan token
            if iszero(amount) {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)
            mstore(ptr, MIDNIGHT_REPAY)
            calldatacopy(add(ptr, 4), argsOffset, argsLength)
            // overwrite inline head words: units (word 1) injected, callback (word 3) forced to 0.
            // onBehalf (word 2) is left as the caller encoded it - repay may target any debtor.
            mstore(add(ptr, 36), amount) // units
            mstore(add(ptr, 100), 0) // callback => no callback, composer pays

            if iszero(call(gas(), target, 0x0, ptr, add(4, argsLength), 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(argsOffset, argsLength)
        }
        return currentOffset;
    }

    /**
     * @notice Redeems credit units for the loan token from a Morpho Midnight market (`withdraw`).
     * @dev `onBehalf` (head word 2) is pinned to `callerAddress`. `units` (head word 1) and `receiver`
     *      (head word 3) are taken as-is from the caller-encoded args.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                       |
     * |--------|----------------|---------------------------------------------------|
     * | 0      | 20             | midnight (target)                                 |
     * | 20     | 2              | argsLength                                        |
     * | 22     | argsLength     | ABI-encoded args (Market, units, onBehalf, receiver) |
     */
    function _midnightWithdraw(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))
            let argsLength := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 20))))
            let argsOffset := add(currentOffset, 22)

            let ptr := mload(0x40)
            mstore(ptr, MIDNIGHT_WITHDRAW)
            calldatacopy(add(ptr, 4), argsOffset, argsLength)
            // pin onBehalf (word 2)
            mstore(add(ptr, 68), callerAddress)

            if iszero(call(gas(), target, 0x0, ptr, add(4, argsLength), 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(argsOffset, argsLength)
        }
        return currentOffset;
    }

    /**
     * @notice Executes an order-book trade on Morpho Midnight (`take`) - the lend/borrow primitive.
     * @dev Consumes an off-chain-signed maker `Offer`: when `offer.buy` is true the taker is the seller
     *      (borrows, incurring debt and receiving `sellerAssets` at `receiverIfTakerIsSeller`); when false
     *      the taker is the buyer (lends, paying `buyerAssets` from the composer and gaining credit units).
     *      `taker` (head word 3) is pinned to `callerAddress`, and `takerCallback` (head word 5) is forced to
     *      zero (atomicity is provided by the surrounding flash loan, not a taker-side callback). `units`
     *      (head word 2) and `receiverIfTakerIsSeller` (head word 4) are taken as-is from the caller-encoded
     *      args. For the lending side the composer must have approved Midnight for the loan token.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                                                          |
     * |--------|----------------|--------------------------------------------------------------------------------------|
     * | 0      | 20             | midnight (target)                                                                    |
     * | 20     | 2              | argsLength                                                                           |
     * | 22     | argsLength     | ABI-encoded args (Offer, ratifierData, units, taker, receiver, takerCallback, takerCallbackData) |
     */
    function _midnightTake(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let target := shr(96, calldataload(currentOffset))
            let argsLength := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 20))))
            let argsOffset := add(currentOffset, 22)

            let ptr := mload(0x40)
            mstore(ptr, MIDNIGHT_TAKE)
            calldatacopy(add(ptr, 4), argsOffset, argsLength)
            // pin taker (word 3) and disable takerCallback (word 5)
            mstore(add(ptr, 100), callerAddress) // taker
            mstore(add(ptr, 164), 0) // takerCallback

            if iszero(call(gas(), target, 0x0, ptr, add(4, argsLength), 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(argsOffset, argsLength)
        }
        return currentOffset;
    }
}
