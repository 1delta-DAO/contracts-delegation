// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Gearbox V3 Credit Accounts.
 *
 * @dev Every Gearbox V3 borrower-side op goes through `CreditFacadeV3.botMulticall(ca, MultiCall[])`
 *      (for existing CAs; the composer is never the CA owner so direct `multicall` is unreachable)
 *      or through `openCreditAccount(onBehalfOf, MultiCall[], refCode)` (for new CAs).
 *      The composer must be pre-registered as a bot on each CA with the minimum permission mask
 *      for the intended flow — see `GEARBOX.md §2` for the UX.
 *
 * @dev Approval target for any `addCollateral` is the **CreditManager**, not the facade. Encoders
 *      emit one `APPROVE(token, creditManager)` op in front of any supply/repay primitive; the
 *      composer's approval bookkeeping skips repeats.
 *
 * @dev No adapter support by design. Every `MultiCall.target` constructed here is the facade
 *      itself; the generic `gearboxMulticall` op rejects any sub-call whose relayed calldata
 *      doesn't match a facade-recognized selector. External protocol calls are out of scope;
 *      use the composer's native primitives + flash loans for cross-lender logic.
 *
 * @dev Aave-parallel primitives map onto Gearbox ops as follows. Each primitive emits a
 *      single `botMulticall(ca, …)` with a bounded sub-call list plus an optional
 *      `setFullCheckParams(minHF)` tail. Chaining per-primitive composer ops pays N collateral
 *      checks — for multi-action flows prefer `GEARBOX_MULTICALL`:
 *
 *        DEPOSIT  → [addCollateral, (setFullCheckParams)]
 *        BORROW   → [increaseDebt, withdrawCollateral(underlying, amt, to), setFullCheckParams]
 *        REPAY    → [addCollateral(underlying, amt), decreaseDebt(amt)]                  // partial
 *                 → [updateQuota(tok_i, int96.min, 0) × N,
 *                    addCollateral(underlying, balanceOf(this)),
 *                    decreaseDebt(uint256.max),                // CM caps to maxRepayment
 *                    withdrawCollateral(underlying, uint256.max, caller)]                 // full
 *        WITHDRAW → [withdrawCollateral, setFullCheckParams]
 */
abstract contract GearboxV3Lending is ERC20Selectors, Masks, DeltaErrors {
    // ─────────────────────────────────────────────────────────────────────────────
    // Facade multicall inner-op selectors (IDs from ICreditFacadeV3Multicall)
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev addCollateral(address,uint256)
    bytes32 internal constant GEARBOX_ADD_COLLATERAL = 0x6d75b9ee00000000000000000000000000000000000000000000000000000000;

    /// @dev increaseDebt(uint256)
    bytes32 internal constant GEARBOX_INCREASE_DEBT = 0x2b7c7b1100000000000000000000000000000000000000000000000000000000;

    /// @dev decreaseDebt(uint256)
    bytes32 internal constant GEARBOX_DECREASE_DEBT = 0x2a7ba1f700000000000000000000000000000000000000000000000000000000;

    /// @dev withdrawCollateral(address,uint256,address)
    bytes32 internal constant GEARBOX_WITHDRAW_COLLATERAL = 0x1f1088a000000000000000000000000000000000000000000000000000000000;

    /// @dev setFullCheckParams(uint256[],uint16)
    bytes32 internal constant GEARBOX_SET_FULL_CHECK_PARAMS = 0x0768bbfe00000000000000000000000000000000000000000000000000000000;

    /// @dev updateQuota(address,int96,uint96)
    bytes32 internal constant GEARBOX_UPDATE_QUOTA = 0x712c10ad00000000000000000000000000000000000000000000000000000000;

    // ─────────────────────────────────────────────────────────────────────────────
    // Facade entrypoint selectors
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev botMulticall(address,(address,bytes)[])
    bytes32 internal constant GEARBOX_BOT_MULTICALL = 0x7e2ca9db00000000000000000000000000000000000000000000000000000000;

    /// @dev openCreditAccount(address,(address,bytes)[],uint256)
    bytes32 internal constant GEARBOX_OPEN_CREDIT_ACCOUNT = 0x92beab1d00000000000000000000000000000000000000000000000000000000;

    // ─────────────────────────────────────────────────────────────────────────────
    // Constants used when composing inner MultiCall arrays
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev int96.min — the "fully disable quota" sentinel documented in
    ///      `ICreditFacadeV3Multicall.updateQuota`.
    int96 internal constant GEARBOX_INT96_MIN = type(int96).min;

    /// @dev `kind` byte values for GEARBOX_MULTICALL:
    ///        0 → botMulticall(ca, calls)
    ///        1 → openCreditAccount(onBehalfOf=callerAddress, calls, referralCode)
    uint256 internal constant GEARBOX_KIND_BOT_MULTICALL = 0;
    uint256 internal constant GEARBOX_KIND_OPEN = 1;

    /**
     * @notice Supplies collateral to a Gearbox V3 Credit Account.
     * @dev Requires the composer to hold `ADD_COLLATERAL_PERMISSION` on `ca` (granted by the CA
     *      owner via a direct `facade.multicall([setBotPermissions(composer, mask)])` — not
     *      through the composer, since `setBotPermissions` is borrower-only).
     *
     *      Amount handling:
     *        - `amount == 0`: composer pulls its own `balanceOf(this)` of `underlying`.
     *        - otherwise:     uses the literal amount. The encoder is responsible for the
     *                         preceding `TRANSFER_FROM(user, composer, amount)` hop.
     *
     *      Token must be pre-approved to the CreditManager (encoder emits `APPROVE(token, cm)`).
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                    |
     * |--------|----------------|------------------------------------------------|
     * | 0      | 20             | underlying                                     |
     * | 20     | 16             | amount (0 = use composer balance)              |
     * | 36     | 20             | creditAccount                                  |
     * | 56     | 20             | creditFacade                                   |
     * | 76     | 2              | minHealthFactor (bps; 0 = skip full check)     |
     */
    function _depositToGearboxV3(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let token := shr(96, calldataload(currentOffset))
            let amount := and(UINT112_MASK, shr(128, calldataload(add(currentOffset, 20))))
            let creditAccount := shr(96, calldataload(add(currentOffset, 36)))
            let creditFacade := shr(96, calldataload(add(currentOffset, 56)))
            let minHF := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 76))))
            currentOffset := add(currentOffset, 78)

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
            let numCalls := 1
            if iszero(iszero(minHF)) { numCalls := 2 }

            // botMulticall(address ca, MultiCall[] calls)
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)         // ca
            mstore(add(ptr, 0x24), 0x40)                   // offset to calls
            mstore(add(ptr, 0x44), numCalls)               // calls.length

            // heads: head[i] is offset from start-of-array-data (== position of calls.length + 32)
            // tuple 0 lives directly after the heads → offset = numCalls * 0x20
            mstore(add(ptr, 0x64), mul(numCalls, 0x20))

            // tuple 0 body: (facade target, bytes addCollateral(token, amount))
            // tuple starts at offset 0x64 + numCalls*0x20 within the args area.
            let tuple0 := add(ptr, add(0x64, mul(numCalls, 0x20)))
            mstore(tuple0, creditFacade)                   // target
            mstore(add(tuple0, 0x20), 0x40)                // callData offset within tuple
            mstore(add(tuple0, 0x40), 0x44)                // callData length = 4 + 2*32 = 68
            mstore(add(tuple0, 0x60), GEARBOX_ADD_COLLATERAL)
            mstore(add(tuple0, 0x64), token)
            mstore(add(tuple0, 0x84), amount)
            // pad to 32 — 68 bytes rounds up to 96 → zero-fill the trailing 28 bytes
            mstore(add(tuple0, 0xa4), 0)

            let endCalls := add(tuple0, 0xc0)              // 0x60 header + 0x60 padded data

            if iszero(iszero(minHF)) {
                // head[1]
                mstore(add(ptr, 0x84), sub(endCalls, add(ptr, 0x64)))
                // tuple 1: setFullCheckParams(uint256[] hints, uint16 minHF) with empty hints
                let tuple1 := endCalls
                mstore(tuple1, creditFacade)
                mstore(add(tuple1, 0x20), 0x40)
                // callData = selector(4) + hints_offset(32) + minHF(32) + hints_len(32) = 100 bytes
                mstore(add(tuple1, 0x40), 0x64)
                mstore(add(tuple1, 0x60), GEARBOX_SET_FULL_CHECK_PARAMS)
                mstore(add(tuple1, 0x64), 0x40)            // offset to hints
                mstore(add(tuple1, 0x84), minHF)           // minHealthFactor
                mstore(add(tuple1, 0xa4), 0)               // hints.length = 0
                // pad: 100 bytes rounds to 128 → 28 zero bytes
                mstore(add(tuple1, 0xc4), 0)
                endCalls := add(tuple1, 0xe0)              // 0x60 header + 0x80 padded data
            }

            let callSize := sub(endCalls, ptr)
            if iszero(call(gas(), creditFacade, 0x0, ptr, callSize, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Borrows underlying from a Gearbox V3 Credit Account and sends it to a receiver.
     * @dev Requires the composer to hold `INCREASE_DEBT_PERMISSION | WITHDRAW_COLLATERAL_PERMISSION`
     *      on `ca`. The `underlying` parameter must match the pool's underlying — mismatch reverts
     *      at the facade during `withdrawCollateral` since the CA has no non-underlying balance to
     *      draw from after `increaseDebt`.
     *
     *      `minHealthFactor` is **not optional** for borrows — the facade default (HF ≥ 1.0 at
     *      10000 bps) is too tight for user-facing leverage. Encoders should pass ≥ 10500.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                    |
     * |--------|----------------|------------------------------------------------|
     * | 0      | 20             | underlying                                     |
     * | 20     | 16             | amount                                         |
     * | 36     | 20             | receiver                                       |
     * | 56     | 20             | creditAccount                                  |
     * | 76     | 20             | creditFacade                                   |
     * | 96     | 2              | minHealthFactor (bps)                          |
     */
    function _borrowFromGearboxV3(uint256 currentOffset) internal returns (uint256) {
        address underlying;
        uint256 amount;
        address receiver;
        address creditAccount;
        address creditFacade;
        uint256 minHF;
        assembly {
            underlying := shr(96, calldataload(currentOffset))
            amount := and(UINT112_MASK, shr(128, calldataload(add(currentOffset, 20))))
            receiver := shr(96, calldataload(add(currentOffset, 36)))
            creditAccount := shr(96, calldataload(add(currentOffset, 56)))
            creditFacade := shr(96, calldataload(add(currentOffset, 76)))
            minHF := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 96))))
        }
        _gearboxBorrowRelay(underlying, amount, receiver, creditAccount, creditFacade, minHF);
        return currentOffset + 98;
    }

    /**
     * @dev Helper — builds and dispatches a `botMulticall(ca, [increaseDebt, withdrawCollateral, setFullCheckParams])`.
     *      Split out so the outer frame doesn't carry both the calldata-readers and the tuple-writers.
     */
    function _gearboxBorrowRelay(
        address underlying,
        uint256 amount,
        address receiver,
        address creditAccount,
        address creditFacade,
        uint256 minHF
    )
        private
    {
        assembly {
            let ptr := mload(0x40)
            // Layout reference:
            //   tuple 0 increaseDebt:          size 0xa0
            //   tuple 1 withdrawCollateral:    size 0xe0
            //   tuple 2 setFullCheckParams:    size 0xe0
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 3)
            mstore(add(ptr, 0x64), 0x60)        // head[0] = 3 * 0x20
            mstore(add(ptr, 0x84), 0x100)       // head[1] = 0x60 + 0xa0
            mstore(add(ptr, 0xa4), 0x1e0)       // head[2] = 0x60 + 0xa0 + 0xe0

            // tuple 0 — increaseDebt(amount) at ptr + 0xc4
            mstore(add(ptr, 0xc4), creditFacade)
            mstore(add(ptr, 0xe4), 0x40)
            mstore(add(ptr, 0x104), 0x24)       // callData len = 36
            mstore(add(ptr, 0x124), GEARBOX_INCREASE_DEBT)
            mstore(add(ptr, 0x128), amount)
            mstore(add(ptr, 0x148), 0)

            // tuple 1 — withdrawCollateral(underlying, amount, receiver) at ptr + 0x164
            mstore(add(ptr, 0x164), creditFacade)
            mstore(add(ptr, 0x184), 0x40)
            mstore(add(ptr, 0x1a4), 0x64)       // callData len = 100
            mstore(add(ptr, 0x1c4), GEARBOX_WITHDRAW_COLLATERAL)
            mstore(add(ptr, 0x1c8), underlying)
            mstore(add(ptr, 0x1e8), amount)
            mstore(add(ptr, 0x208), receiver)
            mstore(add(ptr, 0x228), 0)

            // tuple 2 — setFullCheckParams([], minHF) at ptr + 0x244
            mstore(add(ptr, 0x244), creditFacade)
            mstore(add(ptr, 0x264), 0x40)
            mstore(add(ptr, 0x284), 0x64)
            mstore(add(ptr, 0x2a4), GEARBOX_SET_FULL_CHECK_PARAMS)
            mstore(add(ptr, 0x2a8), 0x40)       // hints offset
            mstore(add(ptr, 0x2c8), minHF)
            mstore(add(ptr, 0x2e8), 0)          // hints.length = 0
            mstore(add(ptr, 0x308), 0)

            if iszero(call(gas(), creditFacade, 0x0, ptr, 0x324, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /**
     * @notice Repays debt on a Gearbox V3 Credit Account. Two shapes discriminated by `amount`:
     *
     *         Partial (`amount ∈ (0, UINT112_MASK)`): emits
     *           `botMulticall(ca, [addCollateral(underlying, amount), decreaseDebt(amount)])`.
     *         If the resulting debt would fall in `(0, minDebt)` the facade reverts with
     *         `BorrowAmountOutOfLimitsException` — the encoder's problem to avoid.
     *
     *         Full (`amount == UINT112_MASK`): emits a multi-step repay-all sequence — strip
     *         every quoted collateral token's quota first (Gearbox forbids non-zero quotas
     *         with zero debt), deposit the pulled underlying, call `decreaseDebt(uint256.max)`
     *         (CM caps internally to `maxRepayment`), then sweep the residue back to
     *         `callerAddress`. No dust, no sporadic reverts. See GEARBOX.md §5.
     *
     * @custom:calldata-offset-table
     * Partial:
     * | Offset | Length (bytes) | Description                                    |
     * |--------|----------------|------------------------------------------------|
     * | 0      | 20             | underlying                                     |
     * | 20     | 16             | amount (partial: > 0 and < UINT112_MASK)       |
     * | 36     | 20             | creditAccount                                  |
     * | 56     | 20             | creditFacade                                   |
     * | 76     | 1              | numQuotedTokens (must be 0 for partial)        |
     *
     * Full (same layout, with amount = UINT112_MASK and N quoted-token entries):
     * | 76     | 1              | numQuotedTokens (N)                            |
     * | 77     | N × 20         | quotedTokens[]                                 |
     */
    function _repayToGearboxV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        // Read the header; dispatch partial vs full path in Solidity so each variant's inner
        // multicall layout can be hand-packed without conditional bookkeeping inside one block.
        address underlying;
        uint128 amount;
        address creditAccount;
        address creditFacade;
        uint256 numQuoted;
        assembly {
            underlying := shr(96, calldataload(currentOffset))
            amount := shr(128, calldataload(add(currentOffset, 20)))
            creditAccount := shr(96, calldataload(add(currentOffset, 36)))
            creditFacade := shr(96, calldataload(add(currentOffset, 56)))
            numQuoted := and(UINT8_MASK, shr(248, calldataload(add(currentOffset, 76))))
        }

        if (amount == uint128(UINT112_MASK)) {
            _repayGearboxV3Full(currentOffset + 77, underlying, creditAccount, creditFacade, numQuoted, callerAddress);
            return currentOffset + 77 + numQuoted * 20;
        }

        if (numQuoted != 0) {
            _invalidOperation();
        }
        _repayGearboxV3Partial(underlying, uint256(amount), creditAccount, creditFacade);
        return currentOffset + 77;
    }

    /**
     * @dev Partial repay: `botMulticall(ca, [addCollateral(underlying, amount), decreaseDebt(amount)])`.
     *      `amount == 0` is rejected — zero-means-balance semantics would risk stranding residue
     *      on the CA if the composer balance exceeds `maxRepayment`. For full repay use the
     *      UINT112_MASK path which explicitly sweeps residue.
     */
    function _repayGearboxV3Partial(address underlying, uint256 amount, address creditAccount, address creditFacade) private {
        if (amount == 0) {
            _invalidOperation();
        }
        assembly {

            let ptr := mload(0x40)
            // 2 inner calls: addCollateral (0xa4 payload padded → tuple 0xc0),
            //                decreaseDebt (0x24 payload padded → tuple 0xa0)
            let numCalls := 2

            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), numCalls)
            mstore(add(ptr, 0x64), mul(numCalls, 0x20))                     // head[0] = 0x40
            mstore(add(ptr, 0x84), add(mul(numCalls, 0x20), 0xc0))          // head[1] = 0x40 + 0xc0 = 0x100

            // tuple 0: addCollateral(underlying, amount) — at ptr + 0x64 + 0x40 = ptr + 0xa4
            let t0 := add(ptr, 0xa4)
            mstore(t0, creditFacade)
            mstore(add(t0, 0x20), 0x40)
            mstore(add(t0, 0x40), 0x44)
            mstore(add(t0, 0x60), GEARBOX_ADD_COLLATERAL)
            mstore(add(t0, 0x64), underlying)
            mstore(add(t0, 0x84), amount)
            mstore(add(t0, 0xa4), 0)

            // tuple 1: decreaseDebt(amount) — at t0 + 0xc0
            let t1 := add(t0, 0xc0)
            mstore(t1, creditFacade)
            mstore(add(t1, 0x20), 0x40)
            mstore(add(t1, 0x40), 0x24)
            mstore(add(t1, 0x60), GEARBOX_DECREASE_DEBT)
            mstore(add(t1, 0x64), amount)
            mstore(add(t1, 0x84), 0)

            let callSize := sub(add(t1, 0xa0), ptr)
            if iszero(call(gas(), creditFacade, 0x0, ptr, callSize, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /**
     * @dev Full repay-all via `botMulticall`. Strips N quotas first, then
     *      `addCollateral(underlying, balanceOf(this))`, then `decreaseDebt(uint256.max)`,
     *      then `withdrawCollateral(underlying, uint256.max, callerAddress)`.
     */
    function _repayGearboxV3Full(
        uint256 quotedTokensOffset,
        address underlying,
        address creditAccount,
        address creditFacade,
        uint256 numQuoted,
        address callerAddress
    )
        private
    {
        // Resolve pulled amount from composer balance first, outside the assembly block, to
        // keep the main builder's stack depth manageable.
        uint256 pulledAmount;
        assembly {
            mstore(0, ERC20_BALANCE_OF)
            mstore(0x04, address())
            if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            pulledAmount := mload(0x0)
        }

        // Write the outer botMulticall header + heads area.
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), add(numQuoted, 3))
        }

        // updateQuota tuples + the three trailing ops. Each helper returns the running cursor
        // (memory position immediately after the last tuple written).
        uint256 cursor = _gearboxWriteQuotaTuples(ptr, quotedTokensOffset, numQuoted, creditFacade);
        cursor = _gearboxWriteAddCollateralTuple(ptr, cursor, creditFacade, underlying, pulledAmount, numQuoted);
        cursor = _gearboxWriteDecreaseDebtMaxTuple(ptr, cursor, creditFacade, numQuoted + 1);
        cursor = _gearboxWriteSweepResidueTuple(ptr, cursor, creditFacade, underlying, callerAddress, numQuoted + 2);

        assembly {
            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(cursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
    }

    /// @dev Helper — writes N `updateQuota(tok_i, int96.min, 0)` tuples + their heads. Returns
    ///      the memory cursor just past the last tuple.
    function _gearboxWriteQuotaTuples(
        uint256 ptr,
        uint256 quotedTokensOffset,
        uint256 numQuoted,
        address creditFacade
    )
        private
        pure
        returns (uint256)
    {
        uint256 cursor;
        assembly {
            let headsBase := add(ptr, 0x64)
            cursor := add(headsBase, mul(add(numQuoted, 3), 0x20))
            for { let i := 0 } lt(i, numQuoted) { i := add(i, 1) } {
                mstore(add(headsBase, mul(i, 0x20)), sub(cursor, headsBase))
                mstore(cursor, creditFacade)
                mstore(add(cursor, 0x20), 0x40)
                mstore(add(cursor, 0x40), 0x64)
                mstore(add(cursor, 0x60), GEARBOX_UPDATE_QUOTA)
                mstore(add(cursor, 0x64), shr(96, calldataload(add(quotedTokensOffset, mul(i, 20)))))
                // int96.min sign-extended to 256 bits
                mstore(add(cursor, 0x84), 0xffffffffffffffffffffffffffffffffffffffff800000000000000000000000)
                mstore(add(cursor, 0xa4), 0)
                mstore(add(cursor, 0xc4), 0)
                cursor := add(cursor, 0xe0)
            }
        }
        return cursor;
    }

    function _gearboxWriteAddCollateralTuple(
        uint256 ptr,
        uint256 cursor,
        address creditFacade,
        address underlying,
        uint256 amount,
        uint256 headIndex
    )
        private
        pure
        returns (uint256)
    {
        assembly {
            mstore(add(add(ptr, 0x64), mul(headIndex, 0x20)), sub(cursor, add(ptr, 0x64)))
            mstore(cursor, creditFacade)
            mstore(add(cursor, 0x20), 0x40)
            mstore(add(cursor, 0x40), 0x44)
            mstore(add(cursor, 0x60), GEARBOX_ADD_COLLATERAL)
            mstore(add(cursor, 0x64), underlying)
            mstore(add(cursor, 0x84), amount)
            mstore(add(cursor, 0xa4), 0)
            cursor := add(cursor, 0xc0)
        }
        return cursor;
    }

    function _gearboxWriteDecreaseDebtMaxTuple(uint256 ptr, uint256 cursor, address creditFacade, uint256 headIndex)
        private
        pure
        returns (uint256)
    {
        assembly {
            mstore(add(add(ptr, 0x64), mul(headIndex, 0x20)), sub(cursor, add(ptr, 0x64)))
            mstore(cursor, creditFacade)
            mstore(add(cursor, 0x20), 0x40)
            mstore(add(cursor, 0x40), 0x24)
            mstore(add(cursor, 0x60), GEARBOX_DECREASE_DEBT)
            mstore(add(cursor, 0x64), MAX_UINT256)
            mstore(add(cursor, 0x84), 0)
            cursor := add(cursor, 0xa0)
        }
        return cursor;
    }

    function _gearboxWriteSweepResidueTuple(
        uint256 ptr,
        uint256 cursor,
        address creditFacade,
        address token,
        address receiver,
        uint256 headIndex
    )
        private
        pure
        returns (uint256)
    {
        assembly {
            mstore(add(add(ptr, 0x64), mul(headIndex, 0x20)), sub(cursor, add(ptr, 0x64)))
            mstore(cursor, creditFacade)
            mstore(add(cursor, 0x20), 0x40)
            mstore(add(cursor, 0x40), 0x64)
            mstore(add(cursor, 0x60), GEARBOX_WITHDRAW_COLLATERAL)
            mstore(add(cursor, 0x64), token)
            mstore(add(cursor, 0x84), MAX_UINT256)
            mstore(add(cursor, 0xa4), receiver)
            mstore(add(cursor, 0xc4), 0)
            cursor := add(cursor, 0xe0)
        }
        return cursor;
    }

    /**
     * @notice Withdraws collateral from a Gearbox V3 Credit Account.
     * @dev Requires the composer to hold `WITHDRAW_COLLATERAL_PERMISSION` on `ca`.
     *      Amount handling:
     *        - `amount == UINT112_MASK`: translated to `type(uint256).max` for Gearbox's own
     *          "sweep full balance" sentinel on `withdrawCollateral`.
     *        - otherwise: literal amount.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                    |
     * |--------|----------------|------------------------------------------------|
     * | 0      | 20             | token                                          |
     * | 20     | 16             | amount (UINT112_MASK = withdraw all)           |
     * | 36     | 20             | receiver                                       |
     * | 56     | 20             | creditAccount                                  |
     * | 76     | 20             | creditFacade                                   |
     * | 96     | 2              | minHealthFactor (bps)                          |
     */
    function _withdrawFromGearboxV3(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let token := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let creditAccount := shr(96, calldataload(add(currentOffset, 56)))
            let creditFacade := shr(96, calldataload(add(currentOffset, 76)))
            let minHF := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 96))))
            currentOffset := add(currentOffset, 98)

            let amount := and(UINT112_MASK, amountData)
            if eq(amount, UINT112_MASK) { amount := MAX_UINT256 }

            let ptr := mload(0x40)
            let numCalls := 1
            if iszero(iszero(minHF)) { numCalls := 2 }

            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), numCalls)
            mstore(add(ptr, 0x64), mul(numCalls, 0x20))

            // tuple 0: withdrawCollateral(token, amount, receiver) — payload 100 → total 0xe0
            let t0 := add(ptr, add(0x64, mul(numCalls, 0x20)))
            mstore(t0, creditFacade)
            mstore(add(t0, 0x20), 0x40)
            mstore(add(t0, 0x40), 0x64)
            mstore(add(t0, 0x60), GEARBOX_WITHDRAW_COLLATERAL)
            mstore(add(t0, 0x64), token)
            mstore(add(t0, 0x84), amount)
            mstore(add(t0, 0xa4), receiver)
            mstore(add(t0, 0xc4), 0)
            let endCalls := add(t0, 0xe0)

            if iszero(iszero(minHF)) {
                mstore(add(ptr, 0x84), sub(endCalls, add(ptr, 0x64)))
                // tuple 1: setFullCheckParams([], minHF)
                let t1 := endCalls
                mstore(t1, creditFacade)
                mstore(add(t1, 0x20), 0x40)
                mstore(add(t1, 0x40), 0x64)
                mstore(add(t1, 0x60), GEARBOX_SET_FULL_CHECK_PARAMS)
                mstore(add(t1, 0x64), 0x40)
                mstore(add(t1, 0x84), minHF)
                mstore(add(t1, 0xa4), 0)
                mstore(add(t1, 0xc4), 0)
                endCalls := add(t1, 0xe0)
            }

            let callSize := sub(endCalls, ptr)
            if iszero(call(gas(), creditFacade, 0x0, ptr, callSize, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Generic multicall relay — lets the encoder stream a compact `MultiCall[]` into
     *         either `botMulticall(ca, …)` or `openCreditAccount(callerAddress, …, refCode)`.
     *         Every sub-call's `target` is implicitly the encoded `creditFacade` — the no-adapter
     *         policy is enforced in code: the encoder supplies only inner calldata.
     *
     * @dev `kind=0` → `botMulticall(creditAccount, calls)`.
     *      `kind=1` → `openCreditAccount(callerAddress, calls, referralCode)` — `onBehalfOf` is
     *                 always `callerAddress` (the authenticated deltaCompose caller), never an
     *                 encoder-supplied address; otherwise a third-party-submitted composer call
     *                 could open a Credit Account owned by another user.
     *
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                               |
     * |--------|----------------|-----------------------------------------------------------|
     * | 0      | 1              | kind (0 = botMulticall, 1 = openCreditAccount)           |
     * | 1      | 20             | creditFacade                                              |
     * | 21     | 20             | creditAccount (kind=0) or padding (kind=1)                |
     * | 41     | 32             | referralCode (kind=1) or padding (kind=0)                 |
     * | 73     | 2              | numCalls (N)                                              |
     * | 75     | Σ              | N sub-calls: innerLen (2) | innerCalldata (innerLen)      |
     */
    function _gearboxMulticall(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        // Pull fixed header fields, then dispatch to a helper so the outer frame stays shallow.
        uint256 kind;
        address creditFacade;
        address creditAccount;
        uint256 numCalls;
        assembly {
            kind := shr(248, calldataload(currentOffset))
            creditFacade := shr(96, calldataload(add(currentOffset, 1)))
            creditAccount := shr(96, calldataload(add(currentOffset, 21)))
            numCalls := and(UINT16_MASK, shr(240, calldataload(add(currentOffset, 73))))
        }
        if (kind > GEARBOX_KIND_OPEN) {
            _invalidOperation();
        }

        if (kind == GEARBOX_KIND_BOT_MULTICALL) {
            return _gearboxRelayBotMulticall(creditFacade, creditAccount, numCalls, currentOffset + 75);
        }
        // kind == GEARBOX_KIND_OPEN
        uint256 referralCode;
        assembly {
            referralCode := calldataload(add(currentOffset, 41))
        }
        return _gearboxRelayOpen(creditFacade, callerAddress, referralCode, numCalls, currentOffset + 75);
    }

    /**
     * @dev Build + dispatch `botMulticall(ca, calls)`. `subCallsOffset` points at the first
     *      sub-call header (innerLen(2) | innerCalldata(innerLen)) in the composer's input.
     *      Returns the offset immediately after the last sub-call.
     */
    function _gearboxRelayBotMulticall(
        address creditFacade,
        address creditAccount,
        uint256 numCalls,
        uint256 subCallsOffset
    )
        private
        returns (uint256 nextOffset)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, GEARBOX_BOT_MULTICALL)
            mstore(add(ptr, 0x04), creditAccount)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), numCalls)
            let headsBase := add(ptr, 0x64)
            let bodyCursor := add(headsBase, mul(numCalls, 0x20))
            let readCursor := subCallsOffset

            for { let i := 0 } lt(i, numCalls) { i := add(i, 1) } {
                let innerLen := and(UINT16_MASK, shr(240, calldataload(readCursor)))
                readCursor := add(readCursor, 2)
                mstore(add(headsBase, mul(i, 0x20)), sub(bodyCursor, headsBase))
                mstore(bodyCursor, creditFacade)
                mstore(add(bodyCursor, 0x20), 0x40)
                mstore(add(bodyCursor, 0x40), innerLen)
                let dataStart := add(bodyCursor, 0x60)
                calldatacopy(dataStart, readCursor, innerLen)
                let paddedLen := and(add(innerLen, 31), not(31))
                if gt(paddedLen, innerLen) {
                    calldatacopy(add(dataStart, innerLen), calldatasize(), sub(paddedLen, innerLen))
                }
                bodyCursor := add(dataStart, paddedLen)
                readCursor := add(readCursor, innerLen)
            }

            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(bodyCursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            nextOffset := readCursor
        }
    }

    /**
     * @dev Build + dispatch `openCreditAccount(onBehalfOf=caller, calls, referralCode)`. Layout
     *      differs from `botMulticall` in the outer head (three static slots vs. one), so the
     *      heads-base offset shifts by 0x20.
     */
    function _gearboxRelayOpen(
        address creditFacade,
        address callerAddress,
        uint256 referralCode,
        uint256 numCalls,
        uint256 subCallsOffset
    )
        private
        returns (uint256 nextOffset)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, GEARBOX_OPEN_CREDIT_ACCOUNT)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), 0x60)
            mstore(add(ptr, 0x44), referralCode)
            mstore(add(ptr, 0x64), numCalls)
            let headsBase := add(ptr, 0x84)
            let bodyCursor := add(headsBase, mul(numCalls, 0x20))
            let readCursor := subCallsOffset

            for { let i := 0 } lt(i, numCalls) { i := add(i, 1) } {
                let innerLen := and(UINT16_MASK, shr(240, calldataload(readCursor)))
                readCursor := add(readCursor, 2)

                mstore(add(headsBase, mul(i, 0x20)), sub(bodyCursor, headsBase))
                mstore(bodyCursor, creditFacade)
                mstore(add(bodyCursor, 0x20), 0x40)
                mstore(add(bodyCursor, 0x40), innerLen)
                calldatacopy(add(bodyCursor, 0x60), readCursor, innerLen)
                let paddedLen := and(add(innerLen, 31), not(31))
                let padLen := sub(paddedLen, innerLen)
                if iszero(iszero(padLen)) {
                    calldatacopy(add(add(bodyCursor, 0x60), innerLen), calldatasize(), padLen)
                }
                bodyCursor := add(bodyCursor, add(0x60, paddedLen))
                readCursor := add(readCursor, innerLen)
            }

            if iszero(call(gas(), creditFacade, 0x0, ptr, sub(bodyCursor, ptr), 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            nextOffset := readCursor
        }
    }
}
