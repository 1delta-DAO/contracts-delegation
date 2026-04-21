# Fluid integration in the 1delta composer

Composer-side reference for Fluid (T1 + smart vaults + fToken). Pairs with the upstream Fluid docs ([direct](FLUID_DIRECT_INTEGRATION.md), [vault custody](FLUID_VAULT_INTEGRATION.md), [smart](FLUID_SMART_VAULT_INTEGRATION.md)) — read those first for protocol semantics.

## What we expose

| Surface | LenderOp | Where |
| --- | --- | --- |
| T1 vault deposit / borrow / repay / withdraw | `DEPOSIT` / `BORROW` / `REPAY` / `WITHDRAW` | [FluidLending.sol](FluidLending.sol) |
| fToken supply / withdraw (ERC4626) | `DEPOSIT_LENDING_TOKEN` / `WITHDRAW_LENDING_TOKEN` | [FluidLending.sol](FluidLending.sol) |
| Smart vault `operate` (T2/T3/T4, combined col + debt) | `FLUID_OPERATE` | [FluidSmartLending.sol](FluidSmartLending.sol) |
| Smart vault `operatePerfect` (share-precise / full exit) | `FLUID_OPERATE_PERFECT` | [FluidSmartLending.sol](FluidSmartLending.sol) |
| NFT-custody flow (user transfers position NFT into composer) | `onERC721Received` hook | [FluidLending.sol](FluidLending.sol) |
| Generic NFT egress | `TransferIds.SWEEP_NFT` | [AssetTransfers.sol](../transfers/AssetTransfers.sol) |

## Lender IDs

```
[ < UP_TO_FLUID = 8000 )       — T1 vault + fToken ops
[ UP_TO_FLUID, UP_TO_FLUID_SMART = 9000 ) — smart vault ops
```

The encoder writes `uint16(UP_TO_FLUID - 1)` for T1 ops and `uint16(UP_TO_FLUID_SMART - 1)` for smart vault ops.

## Conventions

- **Native marker**: `address(0)` everywhere (composer convention). The Fluid `0xEee…EEeE` sentinel never crosses the calldata boundary — composer translates as needed.
- **Amounts**: `uint128` packed with the upper 16 bits free for flags. Decoder applies `UINT112_MASK`.
- **Sentinels**:
  - `0` (T1 deposit / fToken deposit / T1 repay) → use composer balance (`selfbalance()` for native or `balanceOf(this)` for ERC20).
  - `UINT112_MASK` (T1 withdraw / repay) → Fluid's `type(int256).min` "all" sentinel; settled at execution time.
  - `type(int256).max` (smart vault amount slot) → `FLUID_SMART_USE_BALANCE`; resolves to balance via the parallel token slot.

## T1 vault ops — `DEPOSIT / BORROW / REPAY / WITHDRAW`

Single shared calldata body (108 bytes after the 3-byte LENDING + lender header):

| Offset | Length | Field |
| ---: | ---: | --- |
| 0 | 20 | `underlying` (`address(0)` for native) |
| 20 | 16 | `amount` (sentinels: `0` = use balance for deposit/repay; `UINT112_MASK` = max for withdraw/repay) |
| 36 | 32 | `nftId` (`0` = open new position; minted to composer — sweep with `SWEEP_NFT`) |
| 68 | 20 | `receiver` (`to_` in `vault.operate`) |
| 88 | 20 | `vault` |

Encoders: [`CalldataLib.encodeFluidDeposit / Borrow / Repay / Withdraw`](../../../utils/CalldataLib.sol). `Deposit` and `Repay` auto-prepend an `APPROVE` op for ERC20 sides.

Ownership: `BORROW` and `WITHDRAW` need the composer to be `ownerOf(nftId)` — handle via the NFT-custody flow below or by opening within the same `deltaCompose` (then sweep).

## fToken ops — `DEPOSIT_LENDING_TOKEN / WITHDRAW_LENDING_TOKEN`

Standard ERC4626 wrapper around the supply side. 76-byte body:

| Offset | Length | Field |
| ---: | ---: | --- |
| 0 | 20 | `underlying` |
| 20 | 16 | `amount` (deposit `0` = balance; withdraw `UINT112_MASK` = `maxWithdraw(caller)`) |
| 36 | 20 | `receiver` |
| 56 | 20 | `fToken` |

Encoders: `encodeFluidFTokenDeposit / Withdraw`. Withdraw uses `caller` as the ERC4626 `owner` (caller must approve composer for fToken shares).

## Smart vault ops — `FLUID_OPERATE / FLUID_OPERATE_PERFECT`

T2 / T3 / T4 differ only in selector + arity; the layout is uniform:

| Offset | Length | Field |
| ---: | ---: | --- |
| 0 | 1 | `vaultType` (2, 3, 4) |
| 1 | 16 | `callValue` (auto-overridden when a balance-sentinel resolves on a native slot) |
| 17 | 32 | `nftId` |
| 49 | 20 | `receiver` |
| 69 | 20 | `vault` |
| 89 | `numSlots × 20` | `tokens[i]` (parallel to amount slots; only consulted when slot `i` uses the sentinel) |
| next | `numSlots × 32` | `int256` amount + slippage params (see below) |

`numSlots` = 4 for T2/T3, 6 for T4.

**Per-vault slot ordering** (matches Fluid's operate signatures):
- T2 `operate`: `[newColToken0, newColToken1, colSharesMinMax, newDebt]`
- T3 `operate`: `[newCol, newDebtToken0, newDebtToken1, debtSharesMinMax]`
- T4 `operate`: `[newColToken0, newColToken1, colSharesMinMax, newDebtToken0, newDebtToken1, debtSharesMinMax]`
- `operatePerfect` swaps the smart-side amounts for share params and reuses the same shape.

**Balance handling**: write `FLUID_SMART_USE_BALANCE` (`type(int256).max`) into an amount slot to have the composer substitute `balanceOf(this)` of the parallel token (or `selfbalance()` if `tokens[i] == address(0)`). Slippage / share-precise slots (`*MinMax`, `perfectColShares`, `perfectDebtShares`) are literal — the sentinel is not valid there.

Two `*SharesMinMax` caps deserve special note since the sign convention is asymmetric across `operate` vs `operatePerfect`:

- **`operate` smart sides**: `colSharesMinMax_` / `debtSharesMinMax_` are signed, and the sign indicates the operation direction.
  - `> 0`: minting shares — value = **min** col shares to mint, **max** debt shares to mint.
  - `< 0`: burning shares — magnitude = **max** col shares to burn, **min** debt shares to burn.
  - `0`: disallowed if any token amount on the same side is non-zero. Use `type(int128).max` (NOT `type(int256).max`, which collides with the balance sentinel) for a loose upper bound.

- **`operatePerfect` per-token MinMax** (`colTokenXMinMax_` / `debtTokenXMinMax_`): **the sign matches the SHARE-action direction, NOT the token-flow direction** — this is the surprise. Specifically:
  - col side, `perfectColShares < 0` (withdraw, both tokens): both `colTokenXMinMax < 0`, magnitude = min out per token.
  - col side, withdraw into one token only: positive on the kept token, `0` on the skipped one.
  - col side, `perfectColShares > 0` (mint): both `colTokenXMinMax > 0`, magnitude = max in per token.
  - debt side, `perfectDebtShares > 0` (borrow): both `debtTokenXMinMax > 0`, magnitude = min out per token.
  - debt side, `perfectDebtShares < 0` (repay): **both `debtTokenXMinMax < 0`** even though tokens flow IN — magnitude = max in per token. Passing positive caps reverts inside `_debtOperatePerfectPayback` with `VaultDex__InvalidOperateAmount` (errorId `35001`).

**Full close on T4**: the single-call form (`perfectColShares = perfectDebtShares = type(int256).min` in one `operatePerfect`) trips a Fluid DEX invariant. Split into two sequential `operatePerfect` calls — first repay-all on the smart-debt side (col untouched), then burn-all on the smart-col side (debt already zero). See `test_fluid_smart_t4_nft_custody_full_close_two_phase` for the full payload.

Encoders: `encodeFluidSmartOperate{T2,T3,T4}` and `encodeFluidSmartOperatePerfect{T2,T3,T4}`.

## NFT-custody flow — `onERC721Received`

For ops that need composer ownership (`BORROW`, `WITHDRAW`, smart-side variants), the user hands the NFT to the composer with the encoded ops as `data`:

```solidity
VAULT_FACTORY.safeTransferFrom(user, composer, nftId, encodedComposerOps);
```

Auth gates (in [FluidLending.onERC721Received](FluidLending.sol)):
1. `msg.sender == FLUID_VAULT_FACTORY` (`0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d`, hardcoded — same address on every chain via deterministic deployment).
2. `operator == from` — blocks the `setApprovalForAll` attack vector where a third party initiates the transfer with hostile calldata.
3. After the inner dispatch finishes, the composer must NOT still own `tokenId`. The encoded payload must move it out (typically via `SWEEP_NFT`); forgetting reverts atomically instead of leaking the NFT into the stateless composer where the next caller could sweep it.

The dispatch re-enters `_deltaComposeInternal(from, …)`, so token-pull ops in the payload draw from `from`.

## Generic NFT sweep — `TransferIds.SWEEP_NFT`

72-byte body: `collection(20) | receiver(20) | tokenId(32)`. Single `transferFrom(this, receiver, tokenId)`. Works for any ERC721 — no enumeration required. Caller must know `tokenId` up front.

Pair with `DEPOSIT(nftId=0)` to deliver a freshly-opened position — predict the id via `VaultFactory.totalSupply() + 1` (Fluid assigns ids sequentially). For `onERC721Received` flows the id is the incoming `tokenId` already.

## Common flows

**Open + immediately deliver to user** (single `deltaCompose`, `id = VaultFactory.totalSupply() + 1`):
```
DEPOSIT (nftId=0, +col) | SWEEP_NFT(VAULT_FACTORY, user, id)
```

**Borrow more on an existing position** (NFT-custody):
```
data = BORROW(nftId, +amount, user) | SWEEP_NFT(VAULT_FACTORY, user, nftId)
VAULT_FACTORY.safeTransferFrom(user, composer, nftId, data)
```

**Full close** (NFT-custody):
```
data = TRANSFER_FROM(user→composer USDC buffer)
     | REPAY (UINT112_MASK)               // Fluid's int.min sentinel
     | WITHDRAW(UINT112_MASK, to=user)    // ETH straight to user
     | SWEEP USDC (validate, to=user)     // refund repay buffer
     | SWEEP_NFT(VAULT_FACTORY, user, nftId)     // empty NFT back to user
VAULT_FACTORY.safeTransferFrom(user, composer, nftId, data)
```

**Swap → deposit all** (T1):
```
swap... (composer ends with X tokens) | DEPOSIT(amount=0, …)
```

**Balanced LP deposit from balances** (T2 smart col, after a swap that lands both tokens in the composer):
```
amounts = [USE_BALANCE, USE_BALANCE, +int256(minShares), +int256(borrowAmount)]
tokens  = [address(0)  , WSTETH     , address(0)        , address(0)]   // slot 0 native, slot 1 ERC20
```
Composer resolves slot 0 → `selfbalance()` and overrides `callValue`; slot 1 → `balanceOf(WSTETH)`; slots 2/3 stay literal.

**Full close on T4** (smart col + smart debt) — two-phase via `operatePerfect`:
```
data =
  TRANSFER_FROM(user→composer GHO buffer)
| TRANSFER_FROM(user→composer USDC buffer)
| APPROVE GHO → vault | APPROVE USDC → vault
| FLUID_OPERATE_PERFECT(T4):                              // phase 1: repay-all debt
    amounts = [0, 0, 0,                                    //  col untouched
               int.min,                                    //  perfectDebtShares = burn ALL
               -int128.max, -int128.max]                   //  per-token MAX-IN cap (NEGATIVE on burn)
| FLUID_OPERATE_PERFECT(T4):                              // phase 2: burn-all col
    amounts = [int.min, -1, -1,                            //  perfectColShares = burn ALL, loose min-out
               0, 0, 0]                                    //  debt already zero
| SWEEP GHO (validate, to=user) | SWEEP USDC (validate, to=user)
| SWEEP_NFT(VAULT_FACTORY, user, nftId)
VAULT_FACTORY.safeTransferFrom(user, composer, nftId, data)
```
Single-call form (`perfectColShares = perfectDebtShares = int.min` simultaneously) trips a Fluid DEX invariant; the two-phase split is the documented safe pattern.

## Tests

- [test/composer/lending/fluid/FluidLending.t.sol](../../../../test/composer/lending/fluid/FluidLending.t.sol) — 9 tests against the T1 ETH-USDC vault `0x0C8C77B7FF4c2aF7F6CEBbe67350A490E3DD6cB3`. Covers deposit / repay / NFT-custody borrow / NFT-custody withdraw / full close / open + sweep / direct-call auth / setApprovalForAll attack / unswept-NFT revert.
- [test/composer/lending/fluid/FluidLendingSmartT2.t.sol](../../../../test/composer/lending/fluid/FluidLendingSmartT2.t.sol) — 4 tests against the T2 cbBTC/WBTC + USDT vault `0xf7FA55D14C71241e3c970E30C509Ff58b5f5D557`. Covers balanced open / open with balance sentinel / NFT-custody borrow more / full close via `operatePerfect` (single-call works on T2 since debt is simple).
- [test/composer/lending/fluid/FluidLendingSmartT4.t.sol](../../../../test/composer/lending/fluid/FluidLendingSmartT4.t.sol) — 4 tests against the T4 GHO/USDC + GHO/USDC vault `0x20b32C597633f12B44CFAFe0ab27408028CA0f6A`. Covers balanced open / open with balance sentinel / NFT-custody shrink-col / two-phase full close.
