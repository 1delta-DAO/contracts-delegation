// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that wraps Cmpound V3 markets
 */
abstract contract CompoundV3Lending is ERC20Selectors, Masks {
    /// @dev comet.withdrawFrom(address,address,address,uint256) selector — used by both borrow and withdraw
    bytes32 internal constant COMET_WITHDRAW_FROM = 0x2644131800000000000000000000000000000000000000000000000000000000;

    /// @dev comet.supplyTo(address,address,uint256) selector — used by both deposit and repay
    bytes32 internal constant COMET_SUPPLY_TO = 0x4232cd6300000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Withdraws from Compound V3 lending pool
     * @dev Supports both base and collateral token withdrawals; UINT112_MASK = max withdraw.
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 1              | isBase                          |
     * | 57     | 20             | pool                            |
     */
    function _withdrawFromCompoundV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let isBase := calldataload(add(currentOffset, 36))
            let receiver := shr(96, isBase)
            let cometPool := shr(96, calldataload(add(currentOffset, 57)))
            currentOffset := add(currentOffset, 77)

            let amount := and(UINT112_MASK, amountData)
            if eq(amount, 0xffffffffffffffffffffffffffff) {
                switch and(UINT8_MASK, shr(88, isBase))
                case 0 {
                    // userCollateral(address,address) — returns (balance uint128, reserved uint128)
                    mstore(ptr, 0x2b92a07d00000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 0x04), callerAddress)
                    mstore(add(ptr, 0x24), underlying)
                    if iszero(staticcall(gas(), cometPool, ptr, 0x44, ptr, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    amount := and(UINT128_MASK, mload(ptr))
                }
                default {
                    // comet.balanceOf(...) — lending token balance
                    mstore(0, ERC20_BALANCE_OF)
                    mstore(0x04, callerAddress)
                    if iszero(staticcall(gas(), cometPool, 0x0, 0x24, 0x0, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    amount := mload(0x0)
                }
            }

            // comet.withdrawFrom(from=caller, to=receiver, underlying, amount) — identical call to borrow
            mstore(ptr, COMET_WITHDRAW_FROM)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), underlying)
            mstore(add(ptr, 0x64), amount)
            if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Borrows from Compound V3 lending pool
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 20             | comet                           |
     */
    function _borrowFromCompoundV3(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let cometPool := shr(96, calldataload(add(currentOffset, 56)))
            currentOffset := add(currentOffset, 76)

            let amount := and(UINT112_MASK, amountData)

            // comet.withdrawFrom(from=caller, to=receiver, underlying, amount) — identical call to withdraw
            mstore(ptr, COMET_WITHDRAW_FROM)
            mstore(add(ptr, 0x04), callerAddress)
            mstore(add(ptr, 0x24), receiver)
            mstore(add(ptr, 0x44), underlying)
            mstore(add(ptr, 0x64), amount)
            if iszero(call(gas(), cometPool, 0x0, ptr, 0x84, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }

    /**
     * @notice Deposits to Compound V3 lending pool
     * @dev Zero amount uses contract balance
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 20             | comet                           |
     */
    function _depositToCompoundV3(uint256 currentOffset) internal returns (uint256) {
        return _callCometSupplyTo(currentOffset, false);
    }

    /**
     * @notice Repays debt to Compound V3 lending pool
     * @dev Zero amount uses contract balance. Max amount (UINT112_MASK) repays min(balance, debt).
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 20             | comet                           |
     */
    function _repayToCompoundV3(uint256 currentOffset) internal returns (uint256) {
        return _callCometSupplyTo(currentOffset, true);
    }

    /**
     * @notice Shared handler: Compound V3 `supplyTo` is used for BOTH deposit (to own account)
     *         and repay (to a borrower's account — same call, repays their debt first).
     *         Amount handling:
     *         - amount = 0: full contract balance
     *         - isRepay && amount = UINT112_MASK: min(balance, user borrow balance)
     *         - else: as-is
     */
    function _callCometSupplyTo(uint256 currentOffset, bool isRepay) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            let receiver := shr(96, calldataload(add(currentOffset, 36)))
            let comet := shr(96, calldataload(add(currentOffset, 56)))
            currentOffset := add(currentOffset, 76)

            let amount := and(UINT112_MASK, amountData)
            let useBalance := iszero(amount)
            let isMaxRepay := and(isRepay, eq(amount, UINT112_MASK))

            if or(useBalance, isMaxRepay) {
                // contract balance of underlying
                mstore(0, ERC20_BALANCE_OF)
                mstore(0x04, address())
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amount := mload(0x0)

                if isMaxRepay {
                    // comet.borrowBalanceOf(receiver)
                    mstore(0, 0x374c49b400000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, receiver)
                    if iszero(staticcall(gas(), comet, 0x0, 0x24, 0x0, 0x20)) {
                        returndatacopy(0, 0, returndatasize())
                        revert(0, returndatasize())
                    }
                    let userBorrowBalance := mload(0x0)
                    if gt(amount, userBorrowBalance) { amount := userBorrowBalance }
                }
            }

            let ptr := mload(0x40)
            mstore(ptr, COMET_SUPPLY_TO)
            mstore(add(ptr, 0x04), receiver)
            mstore(add(ptr, 0x24), underlying)
            mstore(add(ptr, 0x44), amount)
            if iszero(call(gas(), comet, 0x0, ptr, 0x64, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }
}
