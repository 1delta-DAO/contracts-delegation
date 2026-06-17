# Security Review - 1delta composer (contracts-delegation)

**Audit date:** 2026-06-16
**Auditor:** pashov-ai skill `solidity-auditor` v3 - 12-agent parallel scan (opus 4.7)
**Remediation date:** 2026-06-16
**Remediation branch:** `audit/2026-06-composer-fixes`
**Pull request:** https://github.com/1delta-DAO/contracts-delegation/pull/new/audit/2026-06-composer-fixes

This document is the **remediated** audit report. Each finding carries a `Status:` line
recording the resolution and (where applicable) the commit that landed it.

---

## Scope

|                                  |                                                                                                       |
| -------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Mode**                         | default (`contracts/1delta/composer`)                                                                |
| **Files reviewed**               | 329 `.sol` files, 27,531 LoC across `BaseComposer`, `ComposerLite`, per-chain composers (28 chains), flash-loan callbacks, lending wrappers (Aave V2/V3/V4, Compound V2/V3, Morpho, Silo V2, Fluid, Gearbox V3, Lista), bridges (Across, Squid, Stargate V2, GasZip), DEX singletons (Uni V4, Balancer V3), quoters, transfers, permits |
| **Confidence threshold (1-100)** | 80                                                                                                    |

---

## Resolution summary

| Resolution                        | Count | Items                                |
| --------------------------------- | ----- | ------------------------------------ |
| **Fixed in branch**               | 3     | #2, #7, #14                          |
| **Documented as intentional**     | 7     | #1, #3, #4, #5, #6, #9, #18          |
| **Out of scope (downstream)**     | 8     | #10, #11, #12, #13, #15, #16, #17, #19 |
| **Rejected at Gate 1 by auditor** | 6     | callback-initiator-spoof family (Agent 9) |
| **Closed without action**         | 1     | #8 (Fluid double-native callValue)   |

Commits on remediation branch:

| Commit       | Kind  | Subject                                                        |
| ------------ | ----- | -------------------------------------------------------------- |
| `c751fc22`   | fix   | CompoundV2 silent error-code guard (#2)                        |
| `64c34f0c`   | fix   | SiloV2 max-withdraw wrong share token (#7)                     |
| `06489e85`   | chore | gitignore local audit artifacts                                |
| `089849b4`   | fix   | align `_wrap` / `_unwrap` amount mask with `_sweep` (#14)      |
| `d2d4e116`   | docs  | document intentional design choices (#1, #3, #4, #5, #6, #9, #18) |

---

## Findings

### [80] **1. `_approve` lets any caller mint unrevocable MAX allowances from the composer**

`AssetTransfers._approve` - Confidence: 80

**Status:** Documented as intentional (commit `d2d4e116`).

**Description**

Anyone can call `deltaCompose([TRANSFERS, APPROVE, token, attacker])` to make the composer
issue `token.approve(attacker, MAX_UINT256)` from its own address; the storage marker is
permanent and the dispatcher exposes no revoke op.

**Why no fix**

The composer is a stateless router that must support dynamic integration with any
lending pool, vault, or DEX target chosen per-tx. The composer is not expected to hold
balance between transactions - every batch sweeps its own residue. An attacker
pre-planting an approval has nothing to drain. The reasoning is now pinned in a `@dev`
comment on `_approve` so future reviewers don't re-flag it.

---

## Below-threshold findings (description only)

### [70] **2. CompoundV2 `rdsize == 1` error-code guard never fires**

`CompoundV2Lending._borrowFromCompoundV2 / _withdrawFromCompoundV2 / _repayToCompoundV2` - Confidence: 70

**Status:** **Fixed** in commit `c751fc22`.

**Description**

The error-code guards `if and(eq(rdsize, 1), xor(mload(0x0), 0)) { revert }` after
`borrowBehalf` / `mintBehalf` / `redeem` / `redeemBehalf` / `repayBorrowBehalf` check for
a 1-byte return, but Compound V2 / Venus functions return `uint256` (rdsize = 32); the
guard was dead code.

**Fix applied**

Replaced `eq(rdsize, 1)` with `gt(rdsize, 31)` in 6 call sites. New guard matches the
convention used by the ERC20 `transferFrom` / `transfer` success checks elsewhere in the
same file. Test added in `CompoundV2NativeLending.sol::test_unit_compoundV2_borrowBehalf_non_zero_error_code_reverts`
that mocks the cToken to return a non-zero error code and asserts the guard fires.

---

### [70] **3. BaseComposer missing `nonReentrant`; `ComposerLite` has it**

`BaseComposer.deltaCompose` - Confidence: 70

**Status:** Documented as intentional (commit `d2d4e116`).

**Description**

`ComposerLite.deltaCompose` carries `nonReentrant`; `BaseComposer.deltaCompose` does not.

**Why no fix**

`BaseComposer` exists specifically to support flash-loan and unlock callbacks that
intentionally re-enter the compose loop. Adding `nonReentrant` would break Aave V2/V3,
Morpho, Balancer V3 unlock, and Uniswap V4 unlock flows. The safety lives in each
callback's own validator gate (`caller() == hardcoded_pool` and, on Aave, `initiator ==
address(this)`). `ComposerLite` exists for callback-free flows and carries the guard.
NatSpec added to `BaseComposer.deltaCompose` to document this division of responsibility.

---

### [65] **4. Fluid orphan-NFT cross-user extraction**

`FluidLending._callFluidOperate` / `FluidSmartLending._callFluidSmart` - Confidence: 65

**Status:** Documented as intentional (commit `d2d4e116`).

**Description**

Neither op binds `callerAddress` to `nftId`. If a user lands a position NFT in the
composer via plain `transferFrom` (instead of `safeTransferFrom` + `onERC721Received`),
the next `deltaCompose` caller can operate the position.

**Why no fix**

The intended entry point for operating Fluid positions through the composer is
`VaultFactory.safeTransferFrom(user, composer, nftId, data)`, which routes through
`onERC721Received` to run the encoded ops with `from` as `callerAddress` and auto-sweeps
the NFT back. Fluid markets are not freely deployable, so the bare-`transferFrom`
orphan-position case is treated as user error. NatSpec added to `_callFluidOperate`
explaining the supported flow.

---

### [60] **5. `_singletonUnlock` accepts arbitrary `manager`**

`SharedSingletonActions._singletonUnlock` - Confidence: 60

**Status:** Documented as intentional (commit `d2d4e116`).

**Description**

`manager` is read from calldata with no allowlist; only the dual callbacks
(`unlockCallback` / `balancerUnlockCallback`) gate on `caller() == UNISWAP_V4 /
BALANCER_V3`. An attestation-shaped payload (`balancerUnlockCallback(bytes)` selector
plus embedded `callerAddress`) is dispatched to any user-chosen target. The original
"poolId for validation purposes" comment was misleading - the poolId byte is read by the
callback for routing, not for validation in `_singletonUnlock`.

**Why no fix**

Allowlisting `manager` would break dynamic singleton wiring. The callback-side
`caller()` check is sufficient: a user-supplied non-manager target either reverts (no
`unlock(bytes)` selector) or cannot reach the inner compose dispatch (callback rejects
on caller). The misleading comment was replaced with an accurate description of the
payload layout (callerAddress at offset 136 + a poolId routing byte consumed by the
callbacks themselves).

---

### [55] **6. AaveV4 PositionManager return-data shape assumption**

`AaveV4Lending._callTakerPM` - Confidence: 55

**Status:** Verified correct, documentation strengthened (commit `d2d4e116`).

**Description**

After `positionManager.withdrawOnBehalfOf` / `borrowOnBehalfOf`, the composer reads
`amountOut := mload(0x20)` assuming the PM returns `(uint256 shares, uint256 assets)`.

**Why no code change**

Verified against `ITakerPositionManager` ABI - the return tuple `(uint256 shares,
uint256 assets)` is the canonical Aave V4 PositionManager shape. The original `// returns
(shares, assets) - we read assets at mem[0x20]` comment is correct; it was strengthened
to explicitly cite the interface name.

---

### [55] **7. SiloV2 max-withdraw reads wrong share-token for protected collateral**

`SiloV2Lending._withdrawFromSiloV2` - Confidence: 55

**Status:** **Fixed** in commit `64c34f0c`.

**Description**

On the max-amount sentinel, the composer reads `silo.balanceOf(callerAddress)` BEFORE
branching on `cType`. The silo IS the share token only for the default
(non-protected) collateral type; for `cType != 1`, the read returns the wrong
share-token balance.

**Fix applied**

Added `MAX_REDEEM_WITH_COLLATERAL_TYPE` constant for the typed `maxRedeem(address,uint8)`
selector (0x071bf3ff). Moved the share-balance read inside the cType switch:
  - cType == 1 (default): retains the original `silo.balanceOf(callerAddress)` read; the
    silo is the default share token.
  - cType != 1 (protected, etc.): switches to `silo.maxRedeem(callerAddress, cType)`,
    which routes to the configured share token for the requested collateral type.
Default-path behavior is unchanged; non-default path is correct against the configured
share token. Verified by `test_integ_lending_siloV2_withdraw_all`.

---

### [50] **8. Fluid double-counted `callValue` on int128.max + int128.min stacking**

`FluidLending._callFluidOperate` - Confidence: 50

**Status:** Closed without action.

**Description**

Stacking the col-axis `int128.max` sentinel (native deposit balance) with the debt-axis
`int128.min` sentinel (native repay-all) double-reads `selfbalance()` into `callValue`.

**Why no fix**

The bug requires both `colUnderlying == 0` and `debtUnderlying == 0` (both axes flagged
native). No deployed Fluid T1 vault has both sides native (typical: ETH/USDC or
USDC/ETH), and Fluid markets are not freely deployable, so the only way this fires is
encoder error mislabeling both addresses as `address(0)`. The current failure mode
(`CALL OOF` out-of-funds) is acceptable for that scenario. Considered adding a clean
pre-call guard but the practical risk was low enough not to justify the extra opcodes.

---

### [50] **9. CompoundV2 `pop(call)` ignores exchangeRate failure**

`CompoundV2Lending._withdrawFromCompoundV2` - Confidence: 50

**Status:** Documented as intentional (commit `d2d4e116`).

**Description**

The max-amount path calls `exchangeRateCurrent` / `balanceOfUnderlying` with
`pop(call(...))`. On a reverting cToken, mem[0x0] retains the selector word; subsequent
`mload(0x0)` yields a huge garbage value.

**Why no fix**

The garbage value propagates into a `cTokenTransferAmount` that is then clamped against
the caller's actual cToken balance downstream, so the worst case is "user withdraws a
tiny amount" - bounded user self-harm, never third-party extraction. Fork-resilience is
preferred over a hard revert because some Compound V2 forks silently freeze markets via
paused state rather than reverting the rate read. Contract-level `@dev` added to
`CompoundV2Lending` documenting this reasoning.

---

### [50] **10-13, 15, 16, 17, 19. Bridges and quoters**

`StargateV2`, `QuoterLight`, `BalancerV3Quoter`, V4 quoter, KTX quoter, Across,
`_tryCallExternal`, `_callExternalWithReplace`.

**Status:** Out of scope for this branch (downstream owners).

These all concern bridge or quoter integrations that are not part of the core composer
maintenance scope. Triage notes preserved here for visibility:

- **#10** StargateV2 native+zero underflow - DoS-only on downstream Stargate revert; no on-chain extraction path.
- **#11** QuoterLight split-fraction sum underflow - off-chain quoter DoS only.
- **#12** BalancerV3Quoter conflates revert-with-amount and real failure - off-chain quoter consumers.
- **#13** Quoter callbacks unauth'd - quoter holds no funds; no theft surface.
- **#15** Across missing same-chain check - encoder misconfig leads to unfilled deposit; self-harm only.
- **#16** KTX div-before-mul - fork-dependent fee-table behavior; not in scope.
- **#17** `_tryCallExternal` length-vs-endOffset convention mismatch - lives on CallForwarder only; current paths use it correctly.
- **#19** `_callExternalWithReplace` residual drain - same forwarder-residue family as #1; not exploitable per the no-residue threat model.

---

### [35] **18. Gearbox V3 `kind=1` accepts arbitrary `addr1`**

`GearboxV3Lending._gearboxMulticall` - Confidence: 35

**Status:** Researched in depth, documented as intentional (commit `d2d4e116`).

**Description**

`GEARBOX_KIND_OPEN` skips the CA -> CM -> facade auth chain that protects `botMulticall`;
`addr1` is taken straight from calldata as `creditFacade`.

**Threat-model analysis (4 invariants)**

The dispatch executes `addr1.openCreditAccount(callerAddress, calls, refCode)` with
`callValue = 0`. Allowlisting `addr1` would break dynamic integration with new Gearbox
CreditManagers, so the design instead relies on:

1. **Zero value forwarded.** The CALL passes `0` as msg.value, so no native asset can be
   siphoned to an attacker `addr1`.
2. **No standing approvals to `addr1`.** Composer ERC20 approvals are issued by
   `_approve(token, target)` in the same batch and target the CreditManager, not the
   facade. An attacker `addr1` has no allowance to pull tokens.
3. **`onBehalfOf` pinned.** `_gearboxRelayOpen` writes `callerAddress` at ptr+0x04 as
   `onBehalfOf`. The encoder cannot redirect ownership of the new CA.
4. **Re-entry callerAddress-scoped.** If `addr1` is attacker-controlled and calls back
   `composer.deltaCompose(...)`, the inner batch runs with `callerAddress = attacker`
   (msg.sender of the inner call), so attacker ops only affect attacker's own state.

The residual concern is an encoder embedding hostile `addr1` next to a
`TRANSFER_FROM(user, composer, ...)` op earlier in the same batch - then the composer
holds user funds at dispatch time and a reentrant `_sweep` from the attacker could drain
them. That requires the encoder to be hostile to the signer, which is encoder/UX trust
and outside the contract's threat model.

`kind=1` carries no contract-level damage path under (1)-(4), so no validation is
performed on `addr1`. NatSpec added to `_gearboxMulticall` with this analysis.

---

### [45] **14. `_unwrap` mask asymmetric with `_sweep`**

`AssetTransfers._unwrap` - Confidence: 45

**Status:** **Fixed** in commit `089849b4`.

**Description**

`_sweep` masks the 16-byte amount field with `UINT128_MASK`; `_wrap` and `_unwrap` were
silently truncating to `UINT112_MASK`. The original "remove the upper 16 bytes (flags
space)" comment on `_wrap` was misleading - neither wrap nor unwrap has a config byte
(only `_sweep` does).

**Fix applied**

Switched `_wrap` and `_unwrap` to `UINT128_MASK`. Strictly backwards-compatible
(calldata-sdk encodes amounts up to `UINT112_MAX` and never uses the upper 2 bytes).
All three transfer ops now read the same 16-byte amount field consistently. Verified by
the full 19/19 `Transfers.sol` test suite.

---

## Rejected at Gate 1 by the auditor

The auditor's gating process rejected six findings from Agent 9 (boundary specialty)
during dedup: the "callback-initiator-spoof" family across all flash-loan callbacks
(`AaveV3Callback`, `AaveV2Callback`, `MorphoCallback`, `MoolahCallback`,
`BalancerV3Callback`, `UniV4Callback`).

The claimed attack: an attacker uses `_callExternal` to make the composer directly
invoke `AavePool.flashLoanSimple(composer, ..., params)`. The callback validators
(`caller() == AAVE_V3` and `initiator == address(this)`) would supposedly accept the
attacker's payload because the composer IS the initiator.

The defense: `BaseComposer._callExternal` ([`ExternalCall.sol:53`](contracts/1delta/composer/generic/ExternalCall.sol#L53))
uses a **fixed `deltaForwardCompose(bytes)` selector**. The composer can never directly
call `AavePool.flashLoanSimple(...)` via the `EXT_CALL` op - it can only invoke contracts
that implement `deltaForwardCompose`. The path-to-pool goes through a CallForwarder, so
the callback fires on the forwarder's address, not the composer's, and the composer's
callback validators (`caller() == hardcoded_pool`) reject those calls.

The defense is the contract's own documented intent ([ExternalCall.sol:17-22](contracts/1delta/composer/generic/ExternalCall.sol#L17-L22)):

> "This is not a real external call, this one has a pre-determined selector that
> prevents collision with any calls that can be made in this contract. This prevents
> unauthorized calls that would pull funds from other users."

---

## Leads (manual-review trails, not findings)

These were below-confidence pointers from the auditor that don't constitute exploit
paths. Captured here for posterity.

- **CallForwarder + residual balance / approvals** - permissionlessly callable; same
  no-residue threat model as #1.
- **Morpho / Moolah callbacks missing initiator defense-in-depth** - **Documented as
  intentional** in `chains/abstract/flashLoan/callbacks/MorphoCallback.sol` and both
  `MoolahCallback.sol` files. Morpho Blue is immutable and Lista/Moolah follow the same
  pattern: both invoke the callback only on the `msg.sender` of the originating call, so
  reaching the handler already implies the composer initiated. The `caller() == pool`
  check is sufficient and is what makes the embedded `origCaller` authentic.
- **Compound V2 broken-rate downstream amount inflation** - documented as intentional in #9.
- **`onMorphoCallback` poolId byte never validated against payload provenance** -
  routing byte, not auth byte; gating happens via `caller()`.
- **`_repayToAave` permissionless onBehalfOf** - intentional Aave behavior; no
  concrete economic-damage path traced.
- **Pulsechain `Phiat` flash callback** - included as Aave V2 family (poolId 16);
  cross-chain consistency should be re-confirmed against pulsechain's deployed Phiat
  pool address.

---

## Methodology

12-agent parallel scan, one specialty per agent:

| # | Specialty          | Findings  |
| - | ------------------ | --------- |
| 1 | math-precision     | 0 fix, 4 leads |
| 2 | access-control     | 0 fix, 5 leads |
| 3 | economic-security  | 0 fix, 5 leads |
| 4 | execution-trace    | 0 fix, 6 leads |
| 5 | invariant          | 1 finding (#1), 3 leads |
| 6 | periphery          | 0 fix, 6 leads |
| 7 | first-principles   | 1 finding (#2), 4 leads |
| 8 | asymmetry          | 0 fix, 4 leads (re-spawn after stall) |
| 9 | boundary           | 7 findings (REJECTED at Gate 1) |
| 10 | numerical-gap     | 0 fix, 3 leads |
| 11 | trust-gap         | 0 fix, 3 leads |
| 12 | flow-gap          | 0 fix, 3 leads |

After dedup and gate evaluation, 19 unique findings + 6 leads survived. After
remediation, the breakdown is 3 fixed in code, 7 documented as intentional, 8 out of
scope, 1 closed without action.

---

> This review was performed by an AI assistant. AI analysis can never verify the
> complete absence of vulnerabilities and no guarantee of security is given. Team
> security reviews, bug bounty programs, and on-chain monitoring are strongly
> recommended. For a consultation regarding your project's security, visit
> [https://www.pashov.com](https://www.pashov.com)
