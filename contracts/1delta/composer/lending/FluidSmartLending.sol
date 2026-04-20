// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Fluid Protocol smart vaults (T2 / T3 / T4).
 *
 * @dev Smart vaults differ from T1 (handled by FluidLending) in that one or both sides of the
 *      position is a Fluid DEX LP of two tokens, so `operate()` takes per-token amounts plus a
 *      slippage-shares parameter on each smart side. Type identification:
 *        T1 = 10000 (simple / simple)            — see FluidLending
 *        T2 = 20000 (smart col, simple debt)
 *        T3 = 30000 (simple col, smart debt)
 *        T4 = 40000 (smart col, smart debt)
 *
 * @dev We expose two ops, each gated by `lender ∈ [UP_TO_FLUID, UP_TO_FLUID_SMART)`:
 *        - LenderOps.FLUID_OPERATE         → vault.operate(...)
 *        - LenderOps.FLUID_OPERATE_PERFECT → vault.operatePerfect(...)
 *      The `vaultType` byte (2/3/4) at calldata offset 0 selects the selector and parameter
 *      count. T2 and T3 share the same operate / operatePerfect ABI shape (4 int256 amount
 *      params); T4 has 6 int256 amount params.
 *
 * @dev Balance handling: each int256 param has a parallel token-address slot in the calldata.
 *      To use the composer's current balance for a slot, the encoder writes `type(int256).max`
 *      as the slot's value and the corresponding token address. The composer resolves the
 *      sentinel at execution time:
 *        - tokenAddress != 0 → `balanceOf(this)` of that ERC20
 *        - tokenAddress == 0 → `selfbalance()` (native), and `callValue` is auto-overridden to
 *          the resolved amount (Fluid allows at most one native side, so a single override is
 *          unambiguous)
 *      Slots that hold slippage / share-precise values (`*MinMax`, `perfectColShares`,
 *      `perfectDebtShares`) must NOT use the sentinel — they are literal int256 values and
 *      include Fluid's own `type(int256).min` "all" sentinel, which is distinct from the
 *      balance-sentinel `type(int256).max` we define here. The encoder is responsible for only
 *      placing the sentinel on amount slots.
 *
 * @dev Native handling on slots without the sentinel: encoder pre-computes `callValue`. With
 *      the sentinel on a native amount slot, the composer overrides `callValue` to match.
 *
 * @dev Ownership caveats per FLUID_VAULT_INTEGRATION.md still apply: BORROW/WITHDRAW operations
 *      (negative debt / negative col) require the composer to be ownerOf(nftId).
 */
abstract contract FluidSmartLending is ERC20Selectors, Masks {
    /// @dev selector for VaultT2.operate(uint256,int256,int256,int256,int256,address)
    /// and VaultT3.operate(uint256,int256,int256,int256,int256,address) — identical ABI shape.
    bytes32 internal constant FLUID_T2_T3_OPERATE = 0x10259f2600000000000000000000000000000000000000000000000000000000;

    /// @dev selector for VaultT4.operate(uint256,int256,int256,int256,int256,int256,int256,address)
    bytes32 internal constant FLUID_T4_OPERATE = 0x58cc871e00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for VaultT2.operatePerfect(uint256,int256,int256,int256,int256,address)
    /// and VaultT3.operatePerfect(uint256,int256,int256,int256,int256,address) — identical ABI shape.
    bytes32 internal constant FLUID_T2_T3_OPERATE_PERFECT = 0x0931bf2d00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for VaultT4.operatePerfect(uint256,int256,int256,int256,int256,int256,int256,address)
    bytes32 internal constant FLUID_T4_OPERATE_PERFECT = 0xcc31808e00000000000000000000000000000000000000000000000000000000;

    /// @dev Sentinel: when the encoder writes this as an int256 amount slot, the composer
    ///      replaces it at execution time with `balanceOf(this)` for the slot's token address
    ///      (or `selfbalance()` if the address is 0). Equals `type(int256).max`.
    bytes32 internal constant FLUID_SMART_USE_BALANCE = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /**
     * @notice Calls `operate` on a Fluid smart vault (T2 / T3 / T4).
     * @dev Combined deposit + borrow / withdraw + repay in one call. Smart sides accept either
     *      balanced (both tokens non-zero, same sign) or single-sided (one token zero, DEX
     *      auto-rebalances internally) inputs, protected by the `colSharesMinMax_` /
     *      `debtSharesMinMax_` slippage guards. `type(int256).min` is NOT accepted on per-token
     *      amounts — use FLUID_OPERATE_PERFECT for full exit on a smart side.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length | Description                                                |
     * |--------|--------|------------------------------------------------------------|
     * | 0      | 1      | vaultType (2 = T2, 3 = T3, 4 = T4)                          |
     * | 1      | 16     | callValue (msg.value to forward; auto-overridden when a    |
     * |        |        | balance-sentinel resolves on a native slot)                 |
     * | 17     | 32     | nftId (0 = open new position; minted to composer)           |
     * | 49     | 20     | receiver (to_ — recipient for any tokens out)               |
     * | 69     | 4*20 / 6*20 | tokens[i] — per-slot ERC20 address (0 = native or slot |
     * |        |        | not using balance-sentinel). T2/T3: 4 slots; T4: 6 slots.   |
     * | next   | 4*32 / 6*32 | int256 params (slots match `tokens[i]`):              |
     * |        |        | T2: newColToken0, newColToken1, colSharesMinMax, newDebt    |
     * |        |        | T3: newCol, newDebtToken0, newDebtToken1, debtSharesMinMax  |
     * |        |        | T4: newColToken0, newColToken1, colSharesMinMax, newDebtToken0, newDebtToken1, debtSharesMinMax |
     */
    function _fluidSmartOperate(uint256 currentOffset) internal returns (uint256) {
        return _callFluidSmart(currentOffset, false);
    }

    /**
     * @notice Calls `operatePerfect` on a Fluid smart vault (T2 / T3 / T4).
     * @dev Share-precise variant. Use this for full exit on a smart side: pass
     *      `type(int256).min` for the share parameter (`perfectColShares_` /
     *      `perfectDebtShares_`). Per-token slippage guards (`*MinMax`) bound the actual
     *      token amounts that flow in/out:
     *        - withdrawing both tokens: negative on both, magnitude = min out per token
     *        - withdrawing one token only: positive on the kept token, 0 on the skipped token
     *        - depositing/minting: positive on both, magnitude = max in per token
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length | Description                                                          |
     * |--------|--------|----------------------------------------------------------------------|
     * | 0      | 1      | vaultType (2 = T2, 3 = T3, 4 = T4)                                    |
     * | 1      | 16     | callValue                                                             |
     * | 17     | 32     | nftId                                                                 |
     * | 49     | 20     | receiver                                                              |
     * | 69     | 4*20 / 6*20 | tokens[i] (parallel to int256 slots)                            |
     * | next   | 4*32 / 6*32 | int256 params:                                                  |
     * |        |        | T2: perfectColShares, colToken0MinMax, colToken1MinMax, newDebt        |
     * |        |        | T3: newCol, perfectDebtShares, debtToken0MinMax, debtToken1MinMax      |
     * |        |        | T4: perfectColShares, colToken0MinMax, colToken1MinMax, perfectDebtShares, debtToken0MinMax, debtToken1MinMax |
     */
    function _fluidSmartOperatePerfect(uint256 currentOffset) internal returns (uint256) {
        return _callFluidSmart(currentOffset, true);
    }

    /**
     * @notice Shared dispatcher for Fluid smart-vault `operate` / `operatePerfect`.
     * @dev Layout: 1-byte vaultType | 16-byte callValue | 32-byte nftId | 20-byte receiver |
     *      20-byte vault | numSlots × 20-byte token addresses | numSlots × 32-byte int256 params.
     *      `numSlots` is 4 for T2/T3, 6 for T4. We pick the selector by `vaultType` (T2/T3 share,
     *      T4 differs), iterate each int256 slot resolving the balance-sentinel where present,
     *      and append `receiver` as the trailing address. Return data (operate's int256 deltas,
     *      operatePerfect's int256[] r_) is discarded — smart-vault settlement amounts are
     *      derived from the share parameters and do not compose into other ops here.
     */
    function _callFluidSmart(uint256 currentOffset, bool isPerfect) internal returns (uint256) {
        assembly {
            let vaultType := shr(248, calldataload(currentOffset))
            let callValue := shr(128, calldataload(add(currentOffset, 1)))
            let nftId := calldataload(add(currentOffset, 17))
            let receiver := shr(96, calldataload(add(currentOffset, 49)))
            let vault := shr(96, calldataload(add(currentOffset, 69)))

            // T2/T3 → 4 int256 amount fields; T4 → 6.
            let isT4 := eq(vaultType, 4)
            let numSlots := add(4, mul(isT4, 2))
            let tokenBytes := mul(numSlots, 20) // 80 (T2/T3) or 120 (T4)

            // Reject vaultType outside {2,3,4} early to surface encoder bugs.
            if iszero(or(or(eq(vaultType, 2), eq(vaultType, 3)), isT4)) { revert(0, 0) }

            // Pick selector by (isT4, isPerfect).
            let selector
            switch isPerfect
            case 0 {
                switch isT4
                case 0 { selector := FLUID_T2_T3_OPERATE }
                default { selector := FLUID_T4_OPERATE }
            }
            default {
                switch isT4
                case 0 { selector := FLUID_T2_T3_OPERATE_PERFECT }
                default { selector := FLUID_T4_OPERATE_PERFECT }
            }

            // Build calldata: selector | nftId | <amountFields> | receiver
            let ptr := mload(0x40)
            mstore(ptr, selector)
            mstore(add(ptr, 0x04), nftId)

            // Token slots start at offset 89; int256 params follow at 89 + tokenBytes.
            let tokenStart := add(currentOffset, 89)
            let amountStart := add(tokenStart, tokenBytes)

            // Iterate amount slots, resolving the balance-sentinel where present.
            let i := 0
            for {} lt(i, numSlots) { i := add(i, 1) } {
                let amount := calldataload(add(amountStart, mul(i, 32)))
                if eq(amount, FLUID_SMART_USE_BALANCE) {
                    let token := shr(96, calldataload(add(tokenStart, mul(i, 20))))
                    switch iszero(token)
                    case 1 {
                        // Native side — selfbalance, and override callValue (Fluid: ≤1 native side).
                        amount := selfbalance()
                        callValue := amount
                    }
                    default {
                        mstore(0, ERC20_BALANCE_OF)
                        mstore(0x04, address())
                        if iszero(staticcall(gas(), token, 0x0, 0x24, 0x0, 0x20)) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }
                        amount := mload(0)
                    }
                }
                mstore(add(ptr, add(0x24, mul(i, 32))), amount)
            }

            mstore(add(ptr, add(0x24, mul(numSlots, 32))), receiver)
            let callDataSize := add(0x44, mul(numSlots, 32))
            if iszero(call(gas(), vault, callValue, ptr, callDataSize, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            currentOffset := add(currentOffset, add(89, add(tokenBytes, mul(32, numSlots))))
        }
        return currentOffset;
    }
}
