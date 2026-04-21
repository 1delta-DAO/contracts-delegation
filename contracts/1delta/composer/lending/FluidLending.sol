// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Fluid Protocol T1 vaults and fTokens.
 *
 * @dev T1 vaults expose a single
 *      `operate(uint256 nftId, int256 newCol, int256 newDebt, address to)` entrypoint returning
 *      `(uint256 nftId_, int256 finalCol, int256 finalDebt)`. A single composer op directly wraps
 *      that call, parameterizing BOTH axes at once with optional sentinels:
 *        colAmount/debtAmount are signed int128 in calldata with:
 *          `0`          → skip axis (newCol/newDebt = 0)
 *          `+N`         → deposit (col) or borrow (debt) literal N
 *          `-N`         → withdraw (col) or repay (debt) literal N
 *          `int128.max` → "use composer balance" (positive direction; deposits only)
 *          `int128.min` → Fluid's "all" sentinel (passed as int256.min on the wire)
 *      When `colUnderlying == address(0)` (native collateral) and colAmount is a positive deposit,
 *      the resolved amount is forwarded as msg.value. Same for native debt + repay. For a native
 *      int128.min repay the composer forwards its entire native balance and lets Fluid refund.
 *
 * @dev Fresh-NFT delivery: when `nftId == 0` on input, Fluid mints a new position NFT to the
 *      composer. If `nftReceiver != 0`, the composer reads the returned `nftId_` out of the
 *      `operate` return data and immediately `transferFrom(this, nftReceiver, nftId_)` on the
 *      VaultFactory. This replaces the old pattern (separate SWEEP_NFT op with off-chain
 *      `totalSupply() + 1` prediction) and is front-run-safe: the id comes from the return value
 *      of the very call that produced it.
 *
 * @dev fTokens are standard ERC4626 supply-side tokens. DEPOSIT_LENDING_TOKEN maps to
 *      `deposit(assets, receiver)`; WITHDRAW_LENDING_TOKEN to `withdraw(assets, receiver, owner)`
 *      with `owner = callerAddress`. Caller must have approved the composer for fToken shares
 *      before withdraw.
 *
 * @dev Ownership caveats (see FLUID.md for the full table):
 *        - positive-col (deposit) / negative-debt (repay) require no ownership — anyone can
 *          supply or repay any nftId.
 *        - positive-debt (borrow) / negative-col (withdraw) require the composer to be
 *          ownerOf(nftId), so the NFT must already be in the composer's custody (or nftId == 0
 *          to open a fresh position which is then minted to the composer).
 *
 * @dev NFT-custody flow: this contract implements `onERC721Received` so users can hand a Fluid
 *      position NFT to the composer for a one-shot custody window. The callback runs the encoded
 *      inner ops and, as a hard-coded post-step, transfers the NFT back to `from` if the composer
 *      still owns it. Users don't need to encode any sweep — it's unconditional.
 */
abstract contract FluidLending is ERC20Selectors, Masks, DeltaErrors {
    /// @dev selector for Fluid VaultT1.operate(uint256,int256,int256,address)
    bytes32 internal constant FLUID_VAULT_OPERATE = 0x032d227600000000000000000000000000000000000000000000000000000000;

    /// @dev selector for ERC4626 deposit(uint256,address)
    bytes32 internal constant ERC4626_DEPOSIT = 0x6e553f6500000000000000000000000000000000000000000000000000000000;

    /// @dev selector for ERC4626 withdraw(uint256,address,address)
    bytes32 internal constant ERC4626_WITHDRAW = 0xb460af9400000000000000000000000000000000000000000000000000000000;

    /// @dev selector for ERC4626 maxWithdraw(address)
    bytes32 internal constant ERC4626_MAX_WITHDRAW = 0xce96cb7700000000000000000000000000000000000000000000000000000000;

    /// @dev Bit pattern for type(int256).min — Fluid's "all" sentinel for operate amounts.
    uint256 internal constant INT256_MIN_BITS = 0x8000000000000000000000000000000000000000000000000000000000000000;

    /// @dev Raw 16-byte pattern for type(int128).min (the sign bit of an int128, alone).
    ///      Used as the calldata sentinel for "Fluid-all" (maps to int256.min on the wire).
    uint256 internal constant INT128_MIN_BITS = 0x80000000000000000000000000000000;

    /// @dev Raw 16-byte pattern for type(int128).max. Used as the calldata sentinel for
    ///      "use composer balance" on the positive deposit direction.
    uint256 internal constant INT128_MAX_BITS = 0x7fffffffffffffffffffffffffffffff;

    /**
     * @notice Single-op wrapper for Fluid T1 `vault.operate`.
     * @dev Combined col + debt call. After the call, if the input `nftId` was 0 and `nftReceiver`
     *      is non-zero, the composer transfers the freshly-minted position NFT to `nftReceiver`
     *      using the `nftId_` that `operate` returned.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length | Description                                                    |
     * |--------|--------|----------------------------------------------------------------|
     * | 0      | 20     | colUnderlying (address(0) for native)                          |
     * | 20     | 20     | debtUnderlying (address(0) for native)                         |
     * | 40     | 16     | colAmount (int128; see sentinels on the contract doc)          |
     * | 56     | 16     | debtAmount (int128)                                            |
     * | 72     | 32     | nftId (0 = open new position, minted to composer)              |
     * | 104    | 20     | receiver (vault's `to_` — recipient of out-flows)              |
     * | 124    | 20     | nftReceiver (0 = keep NFT in composer, non-zero = auto-sweep)  |
     * | 144    | 20     | vault                                                          |
     */
    function _callFluidOperate(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            let callValue := 0

            // ── COL axis ────────────────────────────────────────────────────────
            // raw bit-patterns: 0x80..00 = int128.min (withdraw-all), 0x7f..ff = int128.max (deposit-balance)
            {
                let colRaw := shr(128, calldataload(add(currentOffset, 40)))
                let newCol := 0
                if colRaw {
                    let colUnderlying := shr(96, calldataload(currentOffset))
                    switch colRaw
                    case 0x80000000000000000000000000000000 { newCol := INT256_MIN_BITS }
                    case 0x7fffffffffffffffffffffffffffffff {
                        // use-composer-balance on the deposit side
                        switch iszero(colUnderlying)
                        case 1 {
                            newCol := selfbalance()
                            callValue := newCol
                        }
                        default {
                            mstore(0, ERC20_BALANCE_OF)
                            mstore(0x04, address())
                            if iszero(staticcall(gas(), colUnderlying, 0x0, 0x24, 0x0, 0x20)) {
                                returndatacopy(0, 0, returndatasize())
                                revert(0, returndatasize())
                            }
                            newCol := mload(0x0)
                        }
                    }
                    default {
                        newCol := signextend(15, colRaw)
                        // native + deposit (positive, sign bit clear) → forward as msg.value
                        if iszero(colUnderlying) {
                            if iszero(and(colRaw, 0x80000000000000000000000000000000)) {
                                callValue := add(callValue, newCol)
                            }
                        }
                    }
                }
                mstore(add(ptr, 0x24), newCol)
            }

            // ── DEBT axis ───────────────────────────────────────────────────────
            {
                let debtRaw := shr(128, calldataload(add(currentOffset, 56)))
                let newDebt := 0
                if debtRaw {
                    let debtUnderlying := shr(96, calldataload(add(currentOffset, 20)))
                    switch debtRaw
                    case 0x80000000000000000000000000000000 {
                        newDebt := INT256_MIN_BITS
                        // native repay-all → forward selfbalance(), Fluid refunds excess to `receiver`
                        if iszero(debtUnderlying) { callValue := add(callValue, selfbalance()) }
                    }
                    default {
                        newDebt := signextend(15, debtRaw)
                        // native + repay (negative, sign bit set) → forward |amount|
                        if iszero(debtUnderlying) {
                            if and(debtRaw, 0x80000000000000000000000000000000) {
                                callValue := add(callValue, sub(0, newDebt))
                            }
                        }
                    }
                }
                mstore(add(ptr, 0x44), newDebt)
            }

            // ── operate(nftId, newCol, newDebt, receiver) ───────────────────────
            mstore(ptr, FLUID_VAULT_OPERATE)
            mstore(add(ptr, 0x04), calldataload(add(currentOffset, 72))) // nftId
            mstore(add(ptr, 0x64), shr(96, calldataload(add(currentOffset, 104)))) // receiver
            if iszero(
                call(gas(), shr(96, calldataload(add(currentOffset, 144))), callValue, ptr, 0x84, 0x0, 0x0) // vault
            ) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // ── fresh-mint auto-sweep ──────────────────────────────────────────
            // If the caller asked to mint a new NFT (nftId == 0) and supplied a non-zero
            // nftReceiver, forward the newly-minted id (return-data word 0) to it.
            {
                let nftReceiver := shr(96, calldataload(add(currentOffset, 124)))
                if and(iszero(calldataload(add(currentOffset, 72))), iszero(iszero(nftReceiver))) {
                    returndatacopy(0x0, 0x0, 0x20)
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), address())
                    mstore(add(ptr, 0x24), nftReceiver)
                    mstore(add(ptr, 0x44), mload(0x0))
                    if iszero(call(gas(), FLUID_VAULT_FACTORY, 0, ptr, 0x64, 0x0, 0x0)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
            }

            currentOffset := add(currentOffset, 164)
        }
        return currentOffset;
    }

    /**
     * @notice Supplies underlying to a Fluid fToken (ERC4626) for pure yield.
     * @dev Zero amount uses the contract's underlying balance.
     *      Composer must have prior approve of `underlying` to `fToken`.
     *      Native ETH fTokens use the WETH underlying per Fluid convention; for native deposits
     *      wrap ETH → WETH first via the composer's wrap-native op.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description           |
     * |--------|----------------|-----------------------|
     * | 0      | 20             | underlying            |
     * | 20     | 16             | amount (0 = balance)  |
     * | 36     | 20             | receiver              |
     * | 56     | 20             | fToken                |
     */
    function _depositToFluidFToken(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let fToken := shr(96, calldataload(add(currentOffset, 56)))
            currentOffset := add(currentOffset, 76)

            let amount := and(UINT112_MASK, amountData)
            if iszero(amount) {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)
            // deposit(uint256,address)
            mstore(ptr, ERC4626_DEPOSIT)
            mstore(add(ptr, 0x04), amount)
            mstore(add(ptr, 0x24), receiver)
            if iszero(call(gas(), fToken, 0x0, ptr, 0x44, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Withdraws underlying from a Fluid fToken (ERC4626).
     * @dev `owner` is always callerAddress, so the caller must have approved the composer for
     *      fToken shares (standard ERC4626 allowance pattern).
     *      Max amount (UINT112_MASK) queries fToken.maxWithdraw(callerAddress) — already
     *      respects the Liquidity layer's per-block withdrawal limits.
     * @param currentOffset Current position in the calldata
     * @param callerAddress ERC4626 owner of the fToken shares
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | underlying (ignored)         |
     * | 20     | 16             | amount (UINT112_MASK = max)  |
     * | 36     | 20             | receiver                     |
     * | 56     | 20             | fToken                       |
     */
    function _withdrawFromFluidFToken(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let fToken := shr(96, calldataload(add(currentOffset, 56)))
            currentOffset := add(currentOffset, 76)

            let amount := and(UINT112_MASK, amountData)
            if eq(amount, UINT112_MASK) {
                // maxWithdraw(callerAddress)
                mstore(0, ERC4626_MAX_WITHDRAW)
                mstore(0x04, callerAddress)
                if iszero(staticcall(gas(), fToken, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)
            // withdraw(uint256 assets, address receiver, address owner)
            mstore(ptr, ERC4626_WITHDRAW)
            mstore(add(ptr, 0x04), amount)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), callerAddress)
            if iszero(call(gas(), fToken, 0x0, ptr, 0x64, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // NFT-custody flow (onERC721Received)
    // ─────────────────────────────────────────────────────────────────────────────

    /// @dev ERC721_RECEIVED magic = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;

    /// @dev selector for ERC721 ownerOf(uint256)
    bytes32 internal constant ERC721_OWNER_OF = 0x6352211e00000000000000000000000000000000000000000000000000000000;

    /// @dev Fluid VaultFactory (ERC721) address — same deterministic deployment across all chains.
    ///      Used as the auth gate for `onERC721Received` and as the target for the fresh-mint
    ///      auto-sweep and the callback's hard-coded post-sweep.
    ///      On chains where Fluid isn't deployed, no contract sits at this address, so the gate
    ///      is naturally inert.
    address internal constant FLUID_VAULT_FACTORY = 0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d;

    /**
     * @dev Forward reference to the composer's compose dispatcher. Implemented by BaseComposer
     *      via the inheritance chain — declared here so `onERC721Received` can re-enter compose
     *      with `from` as the caller.
     */
    function _deltaComposeInternal(address callerAddress, uint256 currentOffset, uint256 calldataLength) internal virtual;

    /**
     * @notice ERC721 receiver hook — entry point for the Fluid NFT-custody flow.
     * @dev When a user calls `VaultFactory.safeTransferFrom(user, composer, nftId, encodedOps)`,
     *      this hook fires, validates auth, executes the encoded composer ops with the user as
     *      the caller, and then unconditionally returns the NFT to `from` if the composer still
     *      owns it. The user does NOT need to encode any sweep op — the callback handles it.
     *
     *      Auth model:
     *        - msg.sender must equal `FLUID_VAULT_FACTORY`. Without this gate any contract could
     *          call `onERC721Received` directly and pass an arbitrary `from`, tricking the
     *          composer into running ops as that victim and consuming their token allowances.
     *        - operator must equal from. Blocks the setApprovalForAll attack: a third party
     *          holding approval on the factory could otherwise initiate a transfer with
     *          attacker-controlled `data` and hijack the position. Requiring operator == from
     *          forces the position owner themselves to initiate.
     *
     *      Position NFT handling (post inner-dispatch):
     *        - If the composer no longer owns `tokenId` (the inner ops moved it) — nothing to do.
     *        - If `ownerOf` reverts (full-close burned the NFT) — nothing to do.
     *        - Otherwise the composer transfers the NFT back to `from`.
     *      This replaces the prior "revert if still owned" safety net: forgetting a sweep in the
     *      encoded ops no longer fails the tx — the NFT is guaranteed to come back to the owner.
     *
     *      Token sweeps for residual ERC20 balances are still the user's responsibility — include
     *      the relevant transfer / sweep ops in the encoded payload.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        // Auth: caller must be the Fluid VaultFactory + transfer must be initiated by the owner.
        assembly {
            if xor(caller(), FLUID_VAULT_FACTORY) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            if xor(operator, from) {
                mstore(0, INVALID_INITIATOR)
                revert(0, 0x4)
            }
        }

        // Re-enter compose with `from` as the caller so that subsequent vault ops pass the
        // ownerOf check and any token-transfer ops in the payload pull from the right user.
        if (data.length > 0) {
            uint256 dataOffset;
            uint256 dataLength = data.length;
            assembly {
                dataOffset := data.offset
            }
            _deltaComposeInternal(from, dataOffset, dataLength);
        }

        // Hard-coded return: if the composer still owns the NFT, ship it back to `from`. If the
        // inner ops already moved it (e.g. an `operate` with nftReceiver set) or the position was
        // burned on a full close, ownerOf either returns a different address or reverts — both
        // cases fall through as a no-op.
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, ERC721_OWNER_OF)
            mstore(add(ptr, 0x04), tokenId)
            if staticcall(gas(), FLUID_VAULT_FACTORY, ptr, 0x24, ptr, 0x20) {
                if eq(mload(ptr), address()) {
                    mstore(ptr, ERC20_TRANSFER_FROM)
                    mstore(add(ptr, 0x04), address())
                    mstore(add(ptr, 0x24), from)
                    mstore(add(ptr, 0x44), tokenId)
                    if iszero(call(gas(), FLUID_VAULT_FACTORY, 0, ptr, 0x64, 0, 0)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                }
            }
        }

        return ERC721_RECEIVED;
    }
}
