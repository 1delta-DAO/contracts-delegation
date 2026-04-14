// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Aave V4 position manager operations.
 * @dev Aave V4 uses a Hub/Spoke architecture with position managers as intermediaries.
 *      - Deposit/Repay go through IGiverPositionManager (caller supplies tokens).
 *        Requires prior ERC20 approve of underlying to the position manager (via _approve).
 *      - Withdraw/Borrow go through ITakerPositionManager (caller receives tokens).
 *        Requires prior approveWithdraw/approveBorrow allowance from onBehalfOf on the position manager.
 *      All parameters (spoke, positionManager, reserveId, etc.) are read from calldata offset.
 *      Direct spoke calls require governance whitelisting, hence the position manager route.
 */
abstract contract AaveV4Lending is ERC20Selectors, Masks {
    /// @dev selector for ISpoke.getUserTotalDebt(uint256,address)
    bytes32 internal constant SPOKE_GET_USER_TOTAL_DEBT = 0x9b7172a600000000000000000000000000000000000000000000000000000000;

    /// @dev selector for ISpoke.getUserSuppliedAssets(uint256,address)
    bytes32 internal constant SPOKE_GET_USER_SUPPLIED_ASSETS = 0xf1568a8900000000000000000000000000000000000000000000000000000000;

    /// @dev Amount encoding: encoders write `uint128(amount)` (16 bytes of calldata) but the
    /// decoder applies `UINT112_MASK` (14 bytes = 112 bits) to reserve the top 16 bits for
    /// future flags (matching the rest of the composer). Amounts above 2^112 - 1 are
    /// silently truncated. For all real-world ERC20 amounts this is safe:
    ///   2^112 ≈ 5.19e33, vs. max realistic supply (USDC 6d: 2^112/1e6 ≈ 5.19e27 tokens).
    /// The sentinel `UINT112_MASK` (= 2^112 - 1) signals "max" for withdraw / repay.

    /**
     * @notice Deposits to Aave V4 via GiverPositionManager.supplyOnBehalfOf
     * @dev Zero amount uses contract balance. Requires prior ERC20 approve to positionManager.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver (= onBehalfOf)         |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    /// @dev selector for IGiverPositionManager.supplyOnBehalfOf(address,uint256,uint256,address)
    bytes32 internal constant GIVER_PM_SUPPLY = 0xfdf3ca7100000000000000000000000000000000000000000000000000000000;

    /// @dev selector for IGiverPositionManager.repayOnBehalfOf(address,uint256,uint256,address)
    bytes32 internal constant GIVER_PM_REPAY = 0x115f67a900000000000000000000000000000000000000000000000000000000;

    function _depositToAaveV4(uint256 currentOffset) internal returns (uint256) {
        return _callGiverPM(currentOffset, GIVER_PM_SUPPLY, false);
    }

    /**
     * @notice Withdraws from Aave V4 via TakerPositionManager.withdrawOnBehalfOf
     * @dev TakerPM has no receiver parameter, so tokens land in this contract and are
     *      forwarded to receiver via transfer. Max amount queries the caller's full supply.
     *      onBehalfOf is always callerAddress to prevent unauthorized withdrawals.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    /// @dev selector for ITakerPositionManager.withdrawOnBehalfOf(address,uint256,uint256,address)
    bytes32 internal constant TAKER_PM_WITHDRAW = 0x0a250c6d00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for ITakerPositionManager.borrowOnBehalfOf(address,uint256,uint256,address)
    bytes32 internal constant TAKER_PM_BORROW = 0x227e1df400000000000000000000000000000000000000000000000000000000;

    function _withdrawFromAaveV4(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        return _callTakerPM(currentOffset, callerAddress, TAKER_PM_WITHDRAW, true);
    }

    /**
     * @notice Borrows from Aave V4 via TakerPositionManager.borrowOnBehalfOf
     * @dev TakerPM has no receiver parameter, so tokens land in this contract and are
     *      forwarded to receiver via transfer.
     *      Requires prior approveBorrow allowance from callerAddress on the positionManager.
     *      onBehalfOf is always callerAddress to prevent unauthorized borrows.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    function _borrowFromAaveV4(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        return _callTakerPM(currentOffset, callerAddress, TAKER_PM_BORROW, false);
    }

    /**
     * @notice Shared handler for TakerPM "taking" operations (withdraw / borrow).
     * @dev Both share an identical calldata layout and PM call structure.
     *      Max-amount handling is only meaningful for withdraw:
     *      - isWithdraw && amount = UINT112_MASK: query caller's full supplied assets from the spoke.
     *      Borrow has no max semantics (users must specify exact amount for safety).
     *      onBehalfOf is always callerAddress to prevent unauthorized position manipulation.
     *      TakerPM has no receiver parameter, so tokens land here and are forwarded if receiver != address(this).
     */
    function _callTakerPM(
        uint256 currentOffset,
        address callerAddress,
        bytes32 selector,
        bool isWithdraw
    )
        internal
        returns (uint256)
    {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let reserveId := calldataload(add(currentOffset, 56))
            let spoke := shr(96, calldataload(add(currentOffset, 88)))
            let positionManager := shr(96, calldataload(add(currentOffset, 108)))
            currentOffset := add(currentOffset, 128)

            let amount := and(UINT112_MASK, amountData)
            let ptr := mload(0x40)

            // withdraw-only: max amount queries caller's full supplied assets from spoke
            if and(isWithdraw, eq(amount, UINT112_MASK)) {
                mstore(ptr, SPOKE_GET_USER_SUPPLIED_ASSETS)
                mstore(add(ptr, 0x04), reserveId)
                mstore(add(ptr, 0x24), callerAddress)
                if iszero(staticcall(gas(), spoke, ptr, 0x44, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(ptr)
            }

            // call PM.{withdraw|borrow}OnBehalfOf(spoke, reserveId, amount, callerAddress)
            mstore(ptr, selector)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), callerAddress)
            // returns (shares, assets) — we read assets at mem[0x20]
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x40)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // Forward tokens to receiver if not this contract
            if xor(receiver, address()) {
                let amountOut := mload(0x20)

                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), amountOut)

                let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)
                let rdsize := returndatasize()
                success := and(success, or(iszero(rdsize), and(gt(rdsize, 31), eq(mload(ptr), 1))))
                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
        return currentOffset;
    }

    bytes32 internal constant CONFIG_PM_SET_USING_AS_COLLATERAL =
        0xf0e302b100000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Toggles collateral status on Aave V4 via ConfigPositionManager.setUsingAsCollateralOnBehalfOf.
     * @dev Requires: ConfigPM is user's approved position manager on the spoke,
     *      and the composer has canSetUsingAsCollateral permission from the user on ConfigPM.
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller (position owner)
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 32             | reserveId                       |
     * | 32     | 1              | flag (0 = disable, 1 = enable)  |
     * | 33     | 20             | spoke                           |
     * | 53     | 20             | configPositionManager           |
     */
    function _setCollateralAaveV4(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let reserveId := calldataload(currentOffset)
            let flagAndAddresses := calldataload(add(currentOffset, 0x20))
            let flag := shr(248, flagAndAddresses)
            let spoke := and(ADDRESS_MASK, shr(88, flagAndAddresses))
            let configPM := shr(96, calldataload(add(currentOffset, 0x35)))
            currentOffset := add(currentOffset, 73)

            let ptr := mload(0x40)
            // setUsingAsCollateralOnBehalfOf(address,uint256,bool,address)
            mstore(ptr, CONFIG_PM_SET_USING_AS_COLLATERAL)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), flag)
            mstore(add(ptr, 0x64), callerAddress)
            if iszero(call(gas(), configPM, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Repays debt to Aave V4 via GiverPositionManager.repayOnBehalfOf
     * @dev Amount handling:
     *      - amount = 0: uses full contract balance of underlying
     *      - amount = max (0xffffffffffffffffffffffffffff): safe max repay — uses min(contract balance, user debt)
     *        querying user debt from the spoke via getUserTotalDebt(reserveId, onBehalfOf).
     *      - otherwise: uses the specified amount
     *      Note: type(uint256).max is NOT allowed by V4's repayOnBehalfOf, but the spoke caps at actual debt.
     *      Requires prior ERC20 approve to positionManager.
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver (= onBehalfOf)         |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    function _repayToAaveV4(uint256 currentOffset) internal returns (uint256) {
        return _callGiverPM(currentOffset, GIVER_PM_REPAY, true);
    }

    /**
     * @notice Shared handler for GiverPM "giving" operations (supply / repay).
     * @dev Both operations share an identical calldata layout and PM call structure.
     *      Amount handling:
     *      - amount = 0: uses full contract balance (both supply and repay)
     *      - amount = UINT112_MASK (max) AND isRepay = true: safe repay clamped to min(balance, debt)
     *      - otherwise: uses the specified amount
     * @param currentOffset Calldata position pointing at the op's data section.
     * @param selector GIVER_PM_SUPPLY or GIVER_PM_REPAY.
     * @param isRepay true for repay path (enables max-clamp-to-debt), false for supply.
     */
    function _callGiverPM(uint256 currentOffset, bytes32 selector, bool isRepay) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let reserveId := calldataload(add(currentOffset, 56))
            let spoke := shr(96, calldataload(add(currentOffset, 88)))
            let positionManager := shr(96, calldataload(add(currentOffset, 108)))
            currentOffset := add(currentOffset, 128)

            let amount := and(UINT112_MASK, amountData)
            let ptr := mload(0x40)

            // Amount = 0 → use contract balance; repay-max → clamp to min(balance, debt)
            let useBalance := iszero(amount)
            let isMaxRepay := and(isRepay, eq(amount, UINT112_MASK))

            if or(useBalance, isMaxRepay) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)

                if isMaxRepay {
                    // fetch user total debt from spoke, clamp to min(balance, debt)
                    mstore(ptr, SPOKE_GET_USER_TOTAL_DEBT)
                    mstore(add(ptr, 0x04), reserveId)
                    mstore(add(ptr, 0x24), receiver)
                    if iszero(staticcall(gas(), spoke, ptr, 0x44, ptr, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    let debtBalance := mload(ptr)
                    if lt(debtBalance, amount) { amount := debtBalance }
                }
            }

            // call PM.{supplyOnBehalfOf|repayOnBehalfOf}(spoke, reserveId, amount, receiver)
            mstore(ptr, selector)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), receiver)
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }
}
