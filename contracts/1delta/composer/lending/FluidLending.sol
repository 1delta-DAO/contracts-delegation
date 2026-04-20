// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Fluid Protocol vaults and fTokens.
 *
 * @dev Fluid VaultT1 exposes a single
 *      `operate(uint256 nftId, int256 newCol, int256 newDebt, address to)` entrypoint that
 *      handles all four core position actions via signed amounts:
 *        +collateral = deposit, -collateral = withdraw, +debt = borrow, -debt = repay.
 *      We map LenderOps DEPOSIT/BORROW/REPAY/WITHDRAW to the corresponding axis-and-sign in
 *      operate(), with `type(int256).min` as the "all" sentinel for full withdraw / full repay.
 *
 * @dev fTokens are standard ERC4626 supply-side tokens. We map DEPOSIT_LENDING_TOKEN to
 *      `deposit(assets, receiver)` and WITHDRAW_LENDING_TOKEN to `withdraw(assets, receiver, owner)`
 *      with `owner = callerAddress`. Caller must have approved the composer for fToken shares
 *      before withdraw.
 *
 * @dev Native handling follows the composer's address(0) convention. The encoder passes
 *      `underlying = address(0)` for a native (ETH) side, and Fluid's own
 *      `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` sentinel never crosses the calldata
 *      boundary. Fluid's msg.value rules are honored:
 *        - native deposit:  msg.value == amount (exact)
 *        - native repay:    msg.value >= amount (excess refunded by Fluid to `to`)
 *      Borrow/withdraw of native always run with msg.value = 0; Fluid sends ETH to `to`.
 *
 * @dev Ownership caveats (see FLUID_DIRECT_INTEGRATION.md for the full table):
 *        - DEPOSIT/REPAY require no ownership — anyone can supply or repay any nftId.
 *        - BORROW/WITHDRAW require the composer to be ownerOf(nftId), so the NFT must already
 *          be in the composer's custody (or nftId == 0 to open a new position which is then
 *          minted to the composer and can be transferred onward by a follow-up op).
 *
 * @dev NFT-custody flow: this contract also implements `onERC721Received` so users can hand a
 *      Fluid position NFT to the composer for a one-shot custody window. The flow is:
 *
 *        1. user calls `VaultFactory.safeTransferFrom(user, composer, nftId, encodedComposerOps)`
 *        2. factory transfers NFT → composer's `onERC721Received` fires
 *        3. composer validates auth (msg.sender == VaultFactory, operator == from)
 *        4. composer re-enters `_deltaComposeInternal(from, ...)` with the encoded ops, which can
 *           now include BORROW/WITHDRAW since the composer is `ownerOf(nftId)`
 *        5. encoded ops MUST move the NFT out of the composer (typically via `SWEEP_NFT`); if
 *           the composer still owns `tokenId` after the inner dispatch, the whole call reverts
 *
 *      The Fluid VaultFactory address is the same on every chain (deterministic deployment), so
 *      it's hardcoded here as `FLUID_VAULT_FACTORY`. On chains where Fluid isn't deployed nothing
 *      legitimately calls `onERC721Received` from that address, so the gate is naturally inert.
 *      Token sweeps are the user's responsibility via ordinary composer transfer ops in the
 *      encoded payload.
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

    /**
     * @notice Deposits collateral into a Fluid vault position via operate(nftId, +amount, 0, to).
     * @dev Zero amount uses contract balance (selfbalance() for native, balanceOf(this) for ERC20).
     *      For non-zero nftId the deposit is credited to that position with no ownership check.
     *      For nftId == 0 a new position is opened — owned by the composer.
     *      For native (underlying == address(0)) `msg.value == amount` is forwarded.
     *      For ERC20 the composer must have prior approve to the vault.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                  |
     * |--------|----------------|----------------------------------------------|
     * | 0      | 20             | underlying (address(0) for native)           |
     * | 20     | 16             | amount (0 = use balance)                     |
     * | 36     | 32             | nftId (0 = open new position)                |
     * | 68     | 20             | receiver (to_; irrelevant for pure deposit)  |
     * | 88     | 20             | vault                                        |
     */
    function _depositToFluid(uint256 currentOffset) internal returns (uint256) {
        return _callFluidOperate(currentOffset, true, true);
    }

    /**
     * @notice Borrows debt from a Fluid vault position via operate(nftId, 0, +amount, receiver).
     * @dev Composer must be ownerOf(nftId). Borrowed tokens land at `receiver`.
     *      For native borrow the vault sends ETH directly to `receiver`.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                  |
     * |--------|----------------|----------------------------------------------|
     * | 0      | 20             | underlying (address(0) for native, ignored)  |
     * | 20     | 16             | amount                                       |
     * | 36     | 32             | nftId                                        |
     * | 68     | 20             | receiver                                     |
     * | 88     | 20             | vault                                        |
     */
    function _borrowFromFluid(uint256 currentOffset) internal returns (uint256) {
        return _callFluidOperate(currentOffset, false, true);
    }

    /**
     * @notice Repays debt to a Fluid vault position via operate(nftId, 0, -amount, to).
     * @dev Amount handling:
     *        - amount == 0:           use Fluid's type(int256).min sentinel (repay ALL).
     *        - amount == UINT112_MASK: use Fluid's type(int256).min sentinel (repay ALL).
     *        - otherwise:             repay exactly `amount` (will revert if > debt).
     *      For native repay, msg.value forwarded equals selfbalance() on the max path
     *      (Fluid refunds the excess to `to`) and equals the literal amount otherwise.
     *      For ERC20 the composer must have prior approve sufficient to cover Fluid's
     *      execution-time debt computation.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                  |
     * |--------|----------------|----------------------------------------------|
     * | 0      | 20             | underlying (address(0) for native)           |
     * | 20     | 16             | amount                                       |
     * | 36     | 32             | nftId                                        |
     * | 68     | 20             | receiver (to_; native excess refund target)  |
     * | 88     | 20             | vault                                        |
     */
    function _repayToFluid(uint256 currentOffset) internal returns (uint256) {
        return _callFluidOperate(currentOffset, false, false);
    }

    /**
     * @notice Withdraws collateral from a Fluid vault position via operate(nftId, -amount, 0, receiver).
     * @dev Composer must be ownerOf(nftId). Amount handling:
     *        - amount == UINT112_MASK: use Fluid's type(int256).min sentinel (withdraw ALL).
     *        - otherwise:              withdraw exactly `amount`.
     *      For native withdraw the vault sends ETH directly to `receiver` (msg.value = 0).
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                                  |
     * |--------|----------------|----------------------------------------------|
     * | 0      | 20             | underlying (address(0) for native, ignored)  |
     * | 20     | 16             | amount                                       |
     * | 36     | 32             | nftId                                        |
     * | 68     | 20             | receiver                                     |
     * | 88     | 20             | vault                                        |
     */
    function _withdrawFromFluid(uint256 currentOffset) internal returns (uint256) {
        return _callFluidOperate(currentOffset, true, false);
    }

    /**
     * @notice Shared dispatcher for all four Fluid vault.operate flows.
     * @dev Builds operate(nftId, newCol, newDebt, receiver):
     *        axisIsCol=true, signIsPositive=true   → DEPOSIT  (newCol=+amount)
     *        axisIsCol=true, signIsPositive=false  → WITHDRAW (newCol=-amount or int.min)
     *        axisIsCol=false, signIsPositive=true  → BORROW   (newDebt=+amount)
     *        axisIsCol=false, signIsPositive=false → REPAY    (newDebt=-amount or int.min)
     *      Supply directions (DEPOSIT, REPAY) resolve amount==0 from the contract balance and
     *      forward msg.value when the side is native (underlying == address(0)).
     *      Take directions (BORROW, WITHDRAW) substitute UINT112_MASK with Fluid's int.min
     *      "all" sentinel; for WITHDRAW that maps to "withdraw entire collateral",
     *      for BORROW the sentinel is irrelevant (Fluid has no max-borrow semantics) and
     *      callers should pass an explicit amount.
     */
    function _callFluidOperate(uint256 currentOffset, bool axisIsCol, bool signIsPositive) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let nftId := calldataload(add(currentOffset, 36))
            let receiver := shr(96, calldataload(add(currentOffset, 68)))
            let vault := shr(96, calldataload(add(currentOffset, 88)))
            currentOffset := add(currentOffset, 108)

            let amount := and(UINT112_MASK, amountData)
            let isNative := iszero(underlying)
            let isMax := eq(amount, UINT112_MASK)

            let opSignedAmount := 0
            let callValue := 0

            switch axisIsCol
            case 1 {
                switch signIsPositive
                case 1 {
                    // DEPOSIT — resolve amount=0 (and treat max sentinel the same way) to local balance
                    if or(iszero(amount), isMax) {
                        switch isNative
                        case 1 { amount := selfbalance() }
                        default {
                            mstore(0, ERC20_BALANCE_OF)
                            mstore(0x04, address())
                            if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                                returndatacopy(0, 0, returndatasize())
                                revert(0, returndatasize())
                            }
                            amount := mload(0x0)
                        }
                    }
                    opSignedAmount := amount
                    if isNative { callValue := amount }
                }
                default {
                    // WITHDRAW — UINT112_MASK → "all" sentinel, else negate
                    switch isMax
                    case 1 { opSignedAmount := INT256_MIN_BITS }
                    default { opSignedAmount := sub(0, amount) }
                }
            }
            default {
                switch signIsPositive
                case 1 {
                    // BORROW — pass +amount
                    opSignedAmount := amount
                }
                default {
                    // REPAY — amount=0 or max → "all" sentinel; else negate
                    switch or(iszero(amount), isMax)
                    case 1 {
                        opSignedAmount := INT256_MIN_BITS
                        // Cover whatever Fluid computes at execution time
                        if isNative { callValue := selfbalance() }
                    }
                    default {
                        opSignedAmount := sub(0, amount)
                        if isNative { callValue := amount }
                    }
                }
            }

            let newCol := 0
            let newDebt := 0
            switch axisIsCol
            case 1 { newCol := opSignedAmount }
            default { newDebt := opSignedAmount }

            // operate(nftId, newCol, newDebt, to)
            let ptr := mload(0x40)
            mstore(ptr, FLUID_VAULT_OPERATE)
            mstore(add(ptr, 0x04), nftId)
            mstore(add(ptr, 0x24), newCol)
            mstore(add(ptr, 0x44), newDebt)
            mstore(add(ptr, 0x64), receiver)
            if iszero(call(gas(), vault, callValue, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
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
    ///      Used as the auth gate for `onERC721Received`. On chains where Fluid isn't deployed,
    ///      no contract sits at this address, so the gate is naturally inert (nothing can ever
    ///      legitimately call `onERC721Received` from this address) and the hook is safe to leave
    ///      unconditionally enabled.
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
     *      this hook fires, validates auth, and executes the encoded composer ops with the user
     *      as the caller (so vault.borrow / vault.withdraw pass the `ownerOf` check on the now-
     *      composer-owned NFT). The encoded ops MUST move the NFT back out of the composer —
     *      typically via `TransferIds.SWEEP_NFT` to the user, but any path that leaves the
     *      composer no longer owning `tokenId` works (including a withdraw-all that leaves the
     *      position empty, since `SWEEP_NFT` then ships the empty NFT off).
     *
     *      Auth model:
     *        - msg.sender must equal `FLUID_VAULT_FACTORY`. Without this gate any contract could
     *          call `onERC721Received` directly and pass an arbitrary `from`, tricking the
     *          composer into running ops as that victim and consuming their token allowances.
     *        - operator must equal from. This blocks the setApprovalForAll attack: a third
     *          party who has been granted approval on the factory could otherwise initiate a
     *          transfer with attacker-controlled `data` and hijack the position. Requiring
     *          operator == from forces the position owner themselves to initiate.
     *        - the composer must NOT still own `tokenId` after the inner dispatch finishes.
     *          Without this, a forgotten `SWEEP_NFT` would leave the NFT stuck in the (stateless)
     *          composer where the next caller could sweep it out. We surface forgetting as an
     *          atomic revert instead of a silent loss.
     *
     *      Token sweeps for residual ERC20 balances are the user's responsibility — include the
     *      relevant transfer / sweep ops in the encoded payload.
     *
     * @param operator The address that initiated the safeTransferFrom on the factory.
     * @param from The previous owner of the NFT (the position owner).
     * @param tokenId The Fluid position NFT id.
     * @param data Composer ops to execute while the NFT is in custody (same encoding as
     *             `deltaCompose`'s argument).
     * @return The ERC721_RECEIVED magic selector on success.
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

        // Safety net: ensure the encoded ops moved the NFT out of the composer. If `ownerOf`
        // reverts (NFT burned by the position-close flow, if Fluid ever burns), the composer
        // certainly doesn't own it — treat that as success.
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, ERC721_OWNER_OF)
            mstore(add(ptr, 0x04), tokenId)
            if staticcall(gas(), FLUID_VAULT_FACTORY, ptr, 0x24, ptr, 0x20) {
                if eq(mload(ptr), address()) {
                    mstore(0, INVALID_OPERATION)
                    revert(0, 0x4)
                }
            }
        }

        return ERC721_RECEIVED;
    }
}
