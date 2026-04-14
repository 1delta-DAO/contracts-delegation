# Aave Lending Tests

Integration tests for Aave-family lending integrations in the composer. Each file targets a different Aave version and tests the composer-level encoding + execution against a forked mainnet (or other chain).

## Files

| File | Lender | Chain | Notes |
|---|---|---|---|
| [AaveLending.sol](AaveLending.sol) | AAVE_V3 | Base | IR-mode borrows (mode = 2). Tests the `_borrowFromAave`/`_repayToAave` paths with non-zero mode. |
| [AaveLendingNoMode.sol](AaveLendingNoMode.sol) | Aave V3 forks (e.g. Spark, Aurelius) | Various | Tests the `mode = 0` branch — Aave forks that dropped IR modes. |
| [AaveV2Lending.sol](AaveV2Lending.sol) | AAVE_V2 | Ethereum | Legacy V2 deposit/borrow/withdraw/repay. |
| [AaveV4Lending.sol](AaveV4Lending.sol) | AAVE_V4 | Ethereum | Hub/Spoke architecture via Position Managers. |
| [aave-v4-interfaces/](aave-v4-interfaces/) | — | — | Source-of-truth interface definitions for V4. See [README](aave-v4-interfaces/README.md) for the user-facing handler reference. |

---

## AaveV4Lending.sol — Test reference

The V4 tests cover both the basic operations and the gasless permit setup paths. All tests use the live Ethereum mainnet deployment (Core Hub `0xCca8…`, Main Spoke `0x94e7…`) at the latest fork block.

### Setup overview

The composer interacts with V4 via three Position Managers, all governance-whitelisted on the Main Spoke:

| PM | Role | Address |
|---|---|---|
| **GiverPM** | `supplyOnBehalfOf`, `repayOnBehalfOf` | `0x17A54b8d6D9C68e7fa1C7112AC998EA1BA51d11e` |
| **TakerPM** | `borrowOnBehalfOf`, `withdrawOnBehalfOf`, allowance management | `0x6c044c0D3801499bCAbfAd458B70880bc518e9F7` |
| **ConfigPM** | `setUsingAsCollateralOnBehalfOf` and other config delegations | `0x51305839CE822a7b4b12AA7D86eA7005052d575c` |

For any delegated operation:
1. The user must approve the relevant PM on the spoke via `setUserPositionManager(pm, true)` (or the gasless `setSelfAsUserPositionManagerWithSig` permit).
2. For TakerPM operations: the user must additionally grant the composer a per-reserve `approveBorrow` / `approveWithdraw` allowance.
3. For ConfigPM operations: the user must additionally grant the composer the `canSetUsingAsCollateral` permission on the ConfigPM.

### Test coverage matrix

| Test | Op | Permit path | Notes |
|---|---|---|---|
| `test_v4_deposit_basic` | supply | direct (pre-approved PM) | Sanity check. |
| `test_v4_borrow_basic` | borrow | direct (pre-approved allowance) | Requires WETH collateral first. |
| `test_v4_withdraw_basic` | withdraw | direct (pre-approved allowance) | |
| `test_v4_repay_basic` | repay | direct (pre-approved PM) | Partial repay. |
| `test_v4_repay_tryMax` | repay | direct | Caller passes `type(uint112).max` → safe max repay clamped to `min(balance, debt)`. |
| `test_v4_withdraw_max` | withdraw | direct | `type(uint112).max` → queries spoke for full supply, withdraws without dust. |
| `test_v4_set_collateral_via_composer` | setCollateral | direct | Toggle on. |
| `test_v4_disable_collateral_via_composer` | setCollateral | direct | Toggle off. |
| `test_v4_borrow_permit_via_composer` | borrow | gasless `approveBorrowWithSig` | Single-tx setup + borrow via permit. |
| `test_v4_withdraw_permit_via_composer` | withdraw | gasless `approveWithdrawWithSig` | Single-tx setup + withdraw via permit. |
| `test_v4_config_permit_via_composer` | setCollateral | gasless `setCanSetUsingAsCollateralPermissionWithSig` | Single-tx ConfigPM permission + collateral toggle. |
| `test_v4_pm_setup_permit_via_composer` | PM approval | gasless `setSelfAsUserPositionManagerWithSig` | Single PM (e.g. GiverPM only). |
| `test_v4_multi_pm_setup_permit_via_composer` | PM approval | gasless `setUserPositionManagersWithSig` | **3 PMs in 1 signature** via the spoke's batch endpoint. |
| `test_v4_zero_amount_deposit_uses_balance` | supply | direct | `amount = 0` → composer sweeps its full underlying balance into the supply. |
| `test_v4_deposit_enable_collateral_borrow_composite` | supply + setCollateral + borrow | direct | Multi-step composition in a single `deltaCompose`. |
| `test_v4_flash_loan_weth_via_morpho_flash` | flashLoan(deposit + setCollateral + borrow) | gasless full setup | Full looped position via Morpho flash loan; setup permits + ops in one tx. |

### Helper functions

The test file exposes signing helpers used by the gasless tests:

| Helper | Returns | Purpose |
|---|---|---|
| `_signPmSetup(pm, spokeDomain, nonce, deadline)` | encoded permit bytes | Sign + encode a single-PM `setSelfAsUserPositionManagerWithSig` permit. |
| `_signPmsBatch(pms, approvals, nonce, deadline)` | encoded permit bytes | Sign + encode a batch `setUserPositionManagersWithSig` permit (multiple PMs in one signature). |
| `_signBorrowPermit(reserveId, deadline)` | encoded permit bytes | Sign + encode a TakerPM `approveBorrowWithSig` permit (composer = spender). |
| `_signWithdrawPermit(reserveId, amount, nonce, deadline)` | encoded permit bytes | Sign + encode a TakerPM `approveWithdrawWithSig` permit. |
| `_signConfigPermit(deadline)` | encoded permit bytes | Sign + encode a ConfigPM `setCanSetUsingAsCollateralPermissionWithSig` permit. |
| `_depositViaComposer(token, user, amount)` | — | Helper: pre-approve PM + transferIn + deposit via composer. |
| `_borrowViaComposer(token, user, amount)` | — | Helper: pre-approve TakerPM + grant allowance + borrow via composer. |
| `_enableCollateral(reserveId, user)` | — | Helper: direct call to `spoke.setUsingAsCollateral` (user is `msg.sender == onBehalfOf`). |

### EIP-712 type hashes used

The test computes signatures against these constants (matching the Spoke / PM contracts):

| Constant | Used for |
|---|---|
| `SET_USER_PM_TYPEHASH` (`0xba01…851a`) | `setUserPositionManagersWithSig` outer hash |
| `PM_UPDATE_TYPEHASH` (`0x187d…2565`) | Each `(pm, approve)` element inside the array |
| `BORROW_PERMIT_TYPEHASH` | Queried from TakerPM at runtime |
| `WITHDRAW_PERMIT_TYPEHASH` | Queried from TakerPM at runtime |
| `SET_CAN_SET_USING_AS_COLLATERAL_PERMISSION_PERMIT_TYPEHASH` | Queried from ConfigPM at runtime |

### Compact signature encoding

All V4 permit handlers consume EIP-2098 compact signatures:

```solidity
bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));
```

The on-chain decoder recovers `v = 27 + (vs >> 255)` and `s = vs & (2^255 - 1)`.

### Deadline encoding

Deadlines are packed as 4-byte `uint32` with a `+1` offset to disambiguate the unset slot:

```solidity
uint32 deadlinePlusOne = uint32(actualDeadline + 1);
```

Max representable deadline ≈ Feb 7, 2106. Forgetting the `+1` causes signature digest mismatch (clean revert, no silent corruption). The `+1` only exists in calldata — the signed EIP-712 struct uses the raw deadline.

### Running the V4 tests

```bash
forge test --match-test test_v4
```

Default RPC: `https://eth.drpc.org` (overridable via `RPC_ETHEREUM_MAINNET` env var). The tests fork the latest block.
