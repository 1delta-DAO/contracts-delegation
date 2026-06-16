# Lending Integration Safeguards

How every lender integration prevents an attacker from borrowing against, or withdrawing
from, a victim's position.

## The one invariant

Every credit-side operation (BORROW, WITHDRAW, REDEEM, and the `transferFrom`-of-collateral
that Aave-style withdrawals require) binds the position owner to **`callerAddress`** — the
authenticated caller — and **never** to an address taken from calldata.

`callerAddress` can only be:

1. `msg.sender` of `deltaCompose` (see [BaseComposer.sol](BaseComposer.sol#L44) /
   [ComposerLite.sol](ComposerLite.sol#L43)), or
2. an `origCaller` that the composer itself injected into a flash-loan / unlock payload,
   recovered inside a callback **only after** `caller()` is validated against a hardcoded
   pool/singleton (and, for Aave, `initiator == address(this)`).

Because the owner axis is pinned to `callerAddress`, a user-supplied `receiver` for a
borrow/withdraw is safe — the funds are drawn from the caller's *own* position and merely
delivered to an address the caller chose. Conversely, a user-supplied `onBehalfOf`/`receiver`
on DEPOSIT/REPAY is harmless because those ops only *give* funds to a position.

The safeguard therefore has two layers per lender:

- **Binding** — the composer passes `callerAddress` as owner/from/onBehalfOf.
- **Pre-authorization** — the lender independently checks that the user actually granted the
  composer the right to act for them (an allowance, a delegation, a manager flag, or a
  bot-permission registry). The user grants this to themselves; it cannot be granted on a
  victim's behalf.

---

## Borrow safeguards

| Lender | On-chain call | Borrower bound to | User must pre-authorize | Source |
|--------|---------------|-------------------|-------------------------|--------|
| Aave V2 / V3 | `pool.borrow(...,onBehalfOf)` | `callerAddress` | Credit delegation (`approveDelegation`) to composer on the debt token | [AaveLending.sol:125](AaveLending.sol#L125) |
| Aave V4 | PM taker op, `onBehalfOf` | `callerAddress` | `approveBorrow` allowance (or `AAVE_V4_BORROW_PERMIT`) scoped to caller→composer | [AaveV4Lending.sol](AaveV4Lending.sol) |
| Compound V2 | `cToken.borrowBehalf(callerAddress, amt)` | `callerAddress` | Comptroller borrow delegation to composer | [CompoundV2Lending.sol:46](CompoundV2Lending.sol#L46) |
| Compound V3 | `comet.withdrawFrom(from=callerAddress,...)` | `callerAddress` | `comet.allow(composer, true)` manager flag | [CompoundV3Lending.sol:92](CompoundV3Lending.sol#L92) |
| Morpho Blue | `morpho.borrow(...,onBehalf=callerAddress, receiver)` | `callerAddress` | `setAuthorization` (or `MORPHO_CREDIT_PERMIT`) for composer as manager | [MorphoLending.sol:90](MorphoLending.sol#L90) |
| Silo V2 | `silo.borrow(...,borrower=callerAddress, receiver)` | `callerAddress` | ERC-4626/Silo allowance or delegation to composer | [SiloV2Lending.sol:174](SiloV2Lending.sol#L174) |
| Gearbox V3 | `facade.botMulticall(ca, [increaseDebt, withdrawCollateral])` | CA whose `borrower == callerAddress` | Composer registered as bot on the CA with the exact permission mask; auth re-derived on-chain CA→CM→facade and `getBorrowerOrRevert == callerAddress` | [GearboxV3Lending.sol:328](GearboxV3Lending.sol#L328), auth [:121](GearboxV3Lending.sol#L121) |
| Lista broker | broker borrow, `user=callerAddress`, `receiver` | `callerAddress` | Moolah-side delegation/allowance to composer | [ListaBrokerLending.sol:59](ListaBrokerLending.sol#L59) |
| Fluid T1 / Smart | `vault.operate(nftId, +debt, ...)` | NFT must be in composer custody; entered only via `onERC721Received` gated on `caller==FLUID_VAULT_FACTORY` and `operator==from`, re-entering with `from` as `callerAddress` | NFT owner moves the position NFT into the composer within the same batch | [FluidLending.sol](FluidLending.sol), [FluidSmartLending.sol](FluidSmartLending.sol) |

## Withdraw safeguards

| Lender | On-chain call | Owner / `from` bound to | User must pre-authorize | Source |
|--------|---------------|-------------------------|-------------------------|--------|
| Aave V2 / V3 | `aToken.transferFrom(callerAddress, composer, amt)` then `pool.withdraw` | `callerAddress` | ERC-20 approve / `permit` of the aToken to composer | [AaveLending.sol:29](AaveLending.sol#L29) |
| Aave V4 | PM taker op, `onBehalfOf` | `callerAddress`; max reads `getUserSuppliedAssets(reserveId, callerAddress)` | `approveWithdraw` allowance (or `AAVE_V4_WITHDRAW_PERMIT`) caller→composer | [AaveV4Lending.sol:157](AaveV4Lending.sol#L157) |
| Compound V2 | `redeemBehalf(callerAddress)` / `transferFrom(callerAddress,...)` / `redeem(callerAddress)` | `callerAddress` | cToken approve or Comptroller redeem delegation to composer | [CompoundV2Lending.sol](CompoundV2Lending.sol) |
| Compound V3 | `comet.withdrawFrom(from=callerAddress, to=receiver,...)` | `callerAddress`; max reads `userCollateral`/`balanceOf(callerAddress)` | `comet.allow(composer, true)` | [CompoundV3Lending.sol:32](CompoundV3Lending.sol#L32) |
| Morpho Blue | `morpho.withdraw[Collateral](...,onBehalf=callerAddress, receiver)` | `callerAddress`; max reads `position(marketId, callerAddress)` | `setAuthorization` for composer | [MorphoLending.sol:377](MorphoLending.sol#L377), [:469](MorphoLending.sol#L469) |
| Silo V2 | `silo.withdraw/redeem(...,owner=callerAddress, receiver)` | `callerAddress`; max reads `silo.balanceOf(callerAddress)` | ERC-4626 allowance to composer | [SiloV2Lending.sol:51](SiloV2Lending.sol#L51) |
| Fluid fToken | ERC-4626 `withdraw(...,owner=callerAddress)`; max `maxWithdraw(callerAddress)` | `callerAddress` | fToken (ERC-4626) allowance to composer | [FluidLending.sol:287](FluidLending.sol#L287) |
| Fluid T1 / Smart | `vault.operate(nftId, -col, ...)` | NFT custody (see borrow row) | Move position NFT into composer | [FluidLending.sol](FluidLending.sol), [FluidSmartLending.sol](FluidSmartLending.sol) |
| Gearbox V3 | `facade.botMulticall(ca, [withdrawCollateral])` | CA whose `borrower == callerAddress` | Bot permission on the CA (see borrow row) | [GearboxV3Lending.sol:121](GearboxV3Lending.sol#L121) |
| ERC-4626 (generic, e.g. Morpho vaults) | `vault.withdraw/redeem(...,owner=callerAddress)` | `callerAddress` | Vault-share (ERC-4626) allowance to composer | [ERC4626Transfers.sol:109](ERC4626/ERC4626Transfers.sol#L109) |

## Callback-origin safeguards (how `callerAddress` survives a flash context)

`callerAddress` is only as trustworthy as the callback it arrives through. Each callback
validates the caller and recovers the injected origin:

| Callback | Caller check | Origin recovery | Extra check | Source |
|----------|--------------|-----------------|-------------|--------|
| Aave V3 flash | `caller()` ∈ {whitelisted V3 pools} | `origCaller` from composer-injected prefix | `initiator == address(this)` | [AaveV3Callback.sol](chains/arbitrum-one/flashLoan/callbacks/AaveV3Callback.sol) |
| Aave V2 flash | `caller()` ∈ {whitelisted V2 pools} | injected prefix | `initiator == address(this)` | [AaveV2Callback.sol](chains/arbitrum-one/flashLoan/callbacks/AaveV2Callback.sol) |
| Morpho flash/supply/repay | `caller() == MORPHO_BLUE` | injected prefix | Morpho only calls back the `flashLoan` initiator | [MorphoCallback.sol](chains/arbitrum-one/flashLoan/callbacks/MorphoCallback.sol) |
| Balancer V3 unlock | `caller() == BALANCER_V3` | injected prefix | custom callback selector | [BalancerV3Callback.sol](chains/arbitrum-one/flashLoan/callbacks/BalancerV3Callback.sol) |
| Uniswap V4 unlock | `caller() == UNISWAP_V4` | injected prefix | PM only calls back the `unlock` caller | [UniV4Callback.sol](chains/arbitrum-one/flashSwap/callbacks/UniV4Callback.sol) |

In each case the composer prepends `callerAddress` when it initiates the flash loan / unlock
(e.g. [AaveV3.sol:54](flashLoan/AaveV3.sol#L54), [Morpho.sol:54](flashLoan/Morpho.sol#L54),
[Shared.sol:55](singletons/Shared.sol#L55)), so the value recovered in the callback is the
genuine authenticated caller and not attacker-supplied bytes.

---

## Notes / non-position safeguards

- **DEPOSIT / REPAY** ops accept a calldata `receiver`/`onBehalfOf` by design — they only add
  funds to a position, so there is nothing to safeguard.
- The **composer holds no user funds or approvals at rest**. The above pre-authorizations are
  grants from the *user* to the composer; none can be created for a victim. See the repo
  security notes on the `APPROVE` op and the "no funds at rest" invariant for the separate
  (non-position) risk surface.
