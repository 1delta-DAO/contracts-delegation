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
 * @dev Fresh-NFT delivery: when the caller passes `nftId == 0`, Fluid mints a new position NFT
 *      to the composer. If `nftReceiver` is non-zero, the composer reads the returned `nftId_`
 *      out of the call's return data and immediately transfers it to `nftReceiver`. This is the
 *      smart-variant counterpart to the T1 fresh-mint auto-sweep — front-run safe because the id
 *      comes from the return value of the very call that produced it.
 *
 * @dev Ownership caveats per FLUID.md still apply: BORROW/WITHDRAW operations (negative debt /
 *      negative col) require the composer to be ownerOf(nftId).
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

    /// @dev Fluid VaultFactory (ERC721) address — same deterministic deployment across all chains.
    ///      Target for the fresh-mint auto-sweep. Mirrored from FluidLending to avoid coupling.
    address internal constant FLUID_SMART_VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;

    /**
     * @notice Calls `operate` on a Fluid smart vault (T2 / T3 / T4).
     * @dev Combined deposit + borrow / withdraw + repay in one call. Smart sides accept either
     *      balanced (both tokens non-zero, same sign) or single-sided (one token zero, DEX
     *      auto-rebalances internally) inputs, protected by the `colSharesMinMax_` /
     *      `debtSharesMinMax_` slippage guards. `type(int256).min` is NOT accepted on per-token
     *      amounts — use FLUID_OPERATE_PERFECT for full exit on a smart side.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     */
    function _fluidSmartOperate(uint256 currentOffset) internal returns (uint256) {
        return _callFluidSmart(currentOffset, false);
    }

    /**
     * @notice Calls `operatePerfect` on a Fluid smart vault (T2 / T3 / T4).
     * @dev Share-precise variant. Use this for full exit on a smart side: pass
     *      `type(int256).min` for the share parameter (`perfectColShares_` /
     *      `perfectDebtShares_`). Per-token slippage guards (`*MinMax`) bound the actual
     *      token amounts that flow in/out — and **the sign matches the SHARE-action direction,
     *      not the token-flow direction**:
     *        - col side, withdrawing both tokens (`perfectColShares < 0`): both `colTokenXMinMax < 0`,
     *          magnitude = min out per token.
     *        - col side, withdrawing into one token only: positive on the kept token, 0 on the skipped one.
     *        - col side, minting (`perfectColShares > 0`): both `colTokenXMinMax > 0`, magnitude = max in per token.
     *        - debt side, repaying (`perfectDebtShares < 0`): both `debtTokenXMinMax < 0`, magnitude = max in
     *          per token. Note: tokens flow IN to the vault, but the slippage caps follow the share action's sign,
     *          which is negative for burn. Passing positive caps here trips Fluid's `VaultDex__InvalidOperateAmount`.
     *        - debt side, borrowing (`perfectDebtShares > 0`): both `debtTokenXMinMax > 0`, magnitude = min out per token.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     */
    function _fluidSmartOperatePerfect(uint256 currentOffset) internal returns (uint256) {
        return _callFluidSmart(currentOffset, true);
    }

    /**
     * @notice Shared dispatcher for Fluid smart-vault `operate` / `operatePerfect`.
     * @dev Layout: 1-byte vaultType | 16-byte callValue | 32-byte nftId | 20-byte receiver |
     *      20-byte nftReceiver | 20-byte vault | numSlots × 20-byte token addresses |
     *      numSlots × 32-byte int256 params.
     *      `numSlots` is 4 for T2/T3, 6 for T4. Pick the selector by `vaultType` (T2/T3 share,
     *      T4 differs), iterate each int256 slot resolving the balance-sentinel where present,
     *      and append `receiver` as the trailing address. After the call, if `nftId == 0` and
     *      `nftReceiver != 0`, read the returned `nftId_` and transfer it to `nftReceiver`.
     * @custom:calldata-offset-table
     * | Offset | Length | Description                                                 |
     * |--------|--------|-------------------------------------------------------------|
     * | 0      | 1      | vaultType (2 = T2, 3 = T3, 4 = T4)                           |
     * | 1      | 16     | callValue                                                    |
     * | 17     | 32     | nftId (0 = open new)                                         |
     * | 49     | 20     | receiver (vault `to_`)                                       |
     * | 69     | 20     | nftReceiver (0 = keep; non-zero = auto-sweep minted NFT)     |
     * | 89     | 20     | vault                                                        |
     * | 109    | n × 20 | tokens[i] (parallel to int256 slots)                         |
     * | next   | n × 32 | int256 params (see variant)                                  |
     */
    function _callFluidSmart(uint256 currentOffset, bool isPerfect) internal returns (uint256) {
        assembly {
            let vaultType := shr(248, calldataload(currentOffset))
            // Reject vaultType outside {2,3,4} early to surface encoder bugs.
            if iszero(or(or(eq(vaultType, 2), eq(vaultType, 3)), eq(vaultType, 4))) { revert(0, 0) }

            // T2/T3 → 4 int256 amount fields; T4 → 6.
            let numSlots := add(4, mul(eq(vaultType, 4), 2))
            let ptr := mload(0x40)

            // Pick selector: pack (isPerfect, isT4) into a 2-bit index.
            switch or(shl(1, isPerfect), eq(vaultType, 4))
            case 0 { mstore(ptr, FLUID_T2_T3_OPERATE) }
            case 1 { mstore(ptr, FLUID_T4_OPERATE) }
            case 2 { mstore(ptr, FLUID_T2_T3_OPERATE_PERFECT) }
            case 3 { mstore(ptr, FLUID_T4_OPERATE_PERFECT) }

            let nftId := calldataload(add(currentOffset, 17))
            // nftId
            mstore(add(ptr, 0x04), nftId)

            // Iterate amount slots, resolving the balance-sentinel where present.
            let callValue := shr(128, calldataload(add(currentOffset, 1)))
            for { let i := 0 } lt(i, numSlots) { i := add(i, 1) } {
                // amount slot i lives at currentOffset + 109 + numSlots*20 + i*32
                let amount := calldataload(add(currentOffset, add(109, add(mul(numSlots, 20), mul(i, 32)))))
                if eq(amount, FLUID_SMART_USE_BALANCE) {
                    // parallel token slot i lives at currentOffset + 109 + i*20
                    let token := shr(96, calldataload(add(currentOffset, add(109, mul(i, 20)))))
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

            // Trailing receiver (vault's to_)
            mstore(add(ptr, add(0x24, mul(numSlots, 32))), shr(96, calldataload(add(currentOffset, 49))))

            if iszero(
                call(
                    gas(),
                    shr(96, calldataload(add(currentOffset, 89))), // vault
                    callValue,
                    ptr,
                    add(0x44, mul(numSlots, 32)),
                    0x0,
                    0x0
                )
            ) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // Fresh-mint auto-sweep.
            let nftReceiver := shr(96, calldataload(add(currentOffset, 69)))
            if and(iszero(nftId), iszero(iszero(nftReceiver))) {
                returndatacopy(0x0, 0x0, 0x20)
                let newNftId := mload(0x0)

                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), address())
                mstore(add(ptr, 0x24), nftReceiver)
                mstore(add(ptr, 0x44), newNftId)
                if iszero(call(gas(), FLUID_SMART_VAULT_FACTORY, 0, ptr, 0x64, 0x0, 0x0)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
            }

            currentOffset := add(currentOffset, add(109, add(mul(numSlots, 20), mul(numSlots, 32))))
        }
        return currentOffset;
    }
}
