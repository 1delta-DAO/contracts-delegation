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
     * | 36     | 20             | onBehalfOf                      |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    function _depositToAaveV4(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let onBehalfOf := shr(96, calldataload(add(currentOffset, 36)))
            let reserveId := calldataload(add(currentOffset, 56))
            let spoke := shr(96, calldataload(add(currentOffset, 88)))
            let positionManager := shr(96, calldataload(add(currentOffset, 108)))
            currentOffset := add(currentOffset, 128)

            let amount := and(UINT112_MASK, amountData)
            // zero means use contract balance
            if iszero(amount) {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }

            let ptr := mload(0x40)
            // selector supplyOnBehalfOf(address,uint256,uint256,address)
            mstore(ptr, 0xfdf3ca7100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), onBehalfOf)
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
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
    function _withdrawFromAaveV4(uint256 currentOffset, address callerAddress) internal returns (uint256) {
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

            // max amount: query caller's full supplied assets from the spoke
            if eq(amount, UINT112_MASK) {
                // selector for getUserSuppliedAssets(uint256,address)
                mstore(ptr, SPOKE_GET_USER_SUPPLIED_ASSETS)
                mstore(add(ptr, 0x04), reserveId)
                mstore(add(ptr, 0x24), callerAddress)
                if iszero(staticcall(gas(), spoke, ptr, 0x44, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(ptr)
            }
            // selector withdrawOnBehalfOf(address,uint256,uint256,address)
            mstore(ptr, 0x0a250c6d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), callerAddress)
            // call returns (withdrawnShares, withdrawnAmount) - we read withdrawnAmount
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x40)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // PM has no receiver param — tokens land in this contract, forward to receiver
            if xor(receiver, address()) {
                let withdrawnAmount := mload(0x20)

                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), withdrawnAmount)

                let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)
                let rdsize := returndatasize()
                success := and(
                    success,
                    or(
                        iszero(rdsize),
                        and(gt(rdsize, 31), eq(mload(ptr), 1))
                    )
                )
                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
        }
        return currentOffset;
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
            // selector borrowOnBehalfOf(address,uint256,uint256,address)
            mstore(ptr, 0x227e1df400000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), callerAddress)
            // call returns (drawnShares, drawnAmount) - we read drawnAmount
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x40)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // PM has no receiver param — tokens land in this contract, forward to receiver
            if xor(receiver, address()) {
                let borrowedAmount := mload(0x20)

                mstore(ptr, ERC20_TRANSFER)
                mstore(add(ptr, 0x04), receiver)
                mstore(add(ptr, 0x24), borrowedAmount)

                let success := call(gas(), underlying, 0, ptr, 0x44, ptr, 32)
                let rdsize := returndatasize()
                success := and(
                    success,
                    or(
                        iszero(rdsize),
                        and(gt(rdsize, 31), eq(mload(ptr), 1))
                    )
                )
                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
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
     * | 36     | 20             | onBehalfOf                      |
     * | 56     | 32             | reserveId                       |
     * | 88     | 20             | spoke                           |
     * | 108    | 20             | positionManager                 |
     */
    function _repayToAaveV4(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let onBehalfOf := shr(96, calldataload(add(currentOffset, 36)))
            let reserveId := calldataload(add(currentOffset, 56))
            let spoke := shr(96, calldataload(add(currentOffset, 88)))
            let positionManager := shr(96, calldataload(add(currentOffset, 108)))
            currentOffset := add(currentOffset, 128)

            let amount := and(UINT112_MASK, amountData)
            let ptr := mload(0x40)

            switch amount
            // zero: use full contract balance
            case 0 {
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)
            }
            // max: safe repay — min(contract balance, user total debt)
            case 0xffffffffffffffffffffffffffff {
                // fetch contract balance of underlying
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)

                // fetch user total debt from spoke (use ptr to avoid clobbering free memory pointer)
                mstore(ptr, SPOKE_GET_USER_TOTAL_DEBT)
                mstore(add(ptr, 0x04), reserveId)
                mstore(add(ptr, 0x24), onBehalfOf)
                if iszero(staticcall(gas(), spoke, ptr, 0x44, ptr, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                let debtBalance := mload(ptr)

                // clamp to min(contract balance, user debt)
                if lt(debtBalance, amount) { amount := debtBalance }
            }
            // selector repayOnBehalfOf(address,uint256,uint256,address)
            mstore(ptr, 0x115f67a900000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), spoke)
            mstore(add(ptr, 0x24), reserveId)
            mstore(add(ptr, 0x44), amount)
            mstore(add(ptr, 0x64), onBehalfOf)
            if iszero(call(gas(), positionManager, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }
}
