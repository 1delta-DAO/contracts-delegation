// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice ERC4626 deposit and withdraw actions
 * @dev Handles ERC4626 vault operations including deposit, mint, withdraw, and redeem
 */
abstract contract ERC4626Transfers is ERC20Selectors, Masks, DeltaErrors {
    /// @dev  mint(...)
    bytes32 private constant ERC4626_MINT = 0x94bf804d00000000000000000000000000000000000000000000000000000000;

    /// @dev  deposit(...)
    bytes32 private constant ERC4626_DEPOSIT = 0x6e553f6500000000000000000000000000000000000000000000000000000000;

    /// @dev  withdraw(...)
    bytes32 private constant ERC4626_WITHDRAW = 0xb460af9400000000000000000000000000000000000000000000000000000000;

    /// @dev  redeem(...)
    bytes32 private constant ERC4626_REDEEM = 0xba08765200000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Deposit to ERC4626 vault (e.g. morpho)
     * @dev Decodes calldata and executes deposit or mint operation on an ERC4626 vault
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | asset                        |
     * | 20     | 20             | vaultContract                |
     * | 40     | 16             | amount (with flags)          |
     * | 56     | 20             | receiver                     |
     */
    function _encodeErc4646Deposit(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)

            // loan token
            let asset := shr(96, calldataload(currentOffset))

            currentOffset := add(currentOffset, 20)

            let vaultContract := shr(96, calldataload(currentOffset))

            currentOffset := add(currentOffset, 20)

            let amount := shr(128, calldataload(currentOffset))
            let amountToDeposit := and(UINT120_MASK, amount)

            currentOffset := add(currentOffset, 16)

            /**
             * check if it is by shares or assets
             */
            switch and(USE_SHARES_FLAG, amount)
            case 0 {
                mstore(ptr, ERC4626_DEPOSIT)
                /**
                 * if the amount is zero, we assume that the contract balance is deposited
                 */
                if iszero(amountToDeposit) {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
                    // call to asset
                    pop(staticcall(gas(), asset, 0x0, 0x24, 0x0, 0x20))
                    // load the retrieved balance
                    amountToDeposit := mload(0x0)
                }
            }
            default { mstore(ptr, ERC4626_MINT) }

            mstore(add(ptr, 0x4), amountToDeposit) // shares or assets
            mstore(add(ptr, 0x24), shr(96, calldataload(currentOffset))) // receiver

            if iszero(call(gas(), vaultContract, 0x0, ptr, 0x44, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }
            currentOffset := add(currentOffset, 20)
        }
        return currentOffset;
    }

    /**
     * @notice Withdraw from ERC4626 vault (e.g. morpho)
     * @dev Decodes calldata and executes withdraw or redeem operation on an ERC4626 vault
     * @param currentOffset Current position in the calldata
     * @param callerAddress Address of the caller
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | vaultContract                |
     * | 20     | 16             | amount (with flags)          |
     * | 36     | 20             | receiver                     |
     */
    function _encodeErc4646Withdraw(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            let ptr := mload(0x40)

            let vaultContract := shr(96, calldataload(currentOffset))

            currentOffset := add(currentOffset, 20)

            let amount := shr(128, calldataload(currentOffset))
            let amountToWithdrawOrRedeem := and(UINT120_MASK, amount)

            currentOffset := add(currentOffset, 16)

            /**
             * check if it is by shares or assets
             */
            switch and(USE_SHARES_FLAG, amount)
            case 0 {
                // plain withdraw amount
                mstore(ptr, ERC4626_WITHDRAW)
            }
            default {
                // note that this covers max withdraw already as the user can apply the
                // static shares amount they own
                mstore(ptr, ERC4626_REDEEM)
            }

            mstore(add(ptr, 0x4), amountToWithdrawOrRedeem) // shares or assets
            mstore(add(ptr, 0x24), shr(96, calldataload(currentOffset))) // receiver
            currentOffset := add(currentOffset, 20)
            mstore(add(ptr, 0x44), callerAddress) // owner

            if iszero(call(gas(), vaultContract, 0x0, ptr, 0x64, 0x0, 0x0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0x0, returndatasize())
            }
        }
        return currentOffset;
    }
}
