// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

// solhint-disable max-line-length

/**
 * @notice Lending base contract that handles Euler V2.
 * A clear distinction is the fact that Euler vault lending actions
 * always exectue through the EVC - through which callers grant borrow & withdrawal permissions.
 * As such, there is no need to implement borrows and withdrawals here, the caller would directly include them
 * in the EVC batch.
 * Deposits are handled as ERC4626 depoists (mint & deposit).
 * The only features that we need to implement is the repay handler and skimmer (mint with direct deposit).
 */
abstract contract EulerLending is ERC20Selectors, Masks, DeltaErrors {
    bytes32 private constant CASH = 0x961be39100000000000000000000000000000000000000000000000000000000;
    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amount                          |
     * | 36     | 20             | receiver                        |
     * | 56     | 20             | vault                           |
     */

    function _repayToEulerV2(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amount at lower bytes
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            // receiver
            let receiver := shr(96, calldataload(add(currentOffset, 36)))

            let amount := and(UINT120_MASK, amountData)
            switch amount
            case 0 {
                // selector for balanceOf(address)
                mstore(0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x04, address())
                // call to token
                pop(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20))
                // load the retrieved balance
                amount := mload(0x0)
            }
            // safe repay maximum: fetch contract balance and user debt and take minimum
            case 0xffffffffffffffffffffffffffff { amount := MAX_UINT256 }

            // get vault
            let vault := shr(96, calldataload(add(currentOffset, 56)))
            // skip vault (end of data)
            currentOffset := add(currentOffset, 76)

            let ptr := mload(0x40)

            // selector repay(uint256,address)
            mstore(ptr, 0xacb7081500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), amount)
            mstore(add(ptr, 0x24), receiver)
            // call vault
            if iszero(call(gas(), vault, 0x0, ptr, 0x44, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }
        }

        return currentOffset;
    }

    /*
     * Efficient deposit without pulling balances directly 
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | underlying                      |
     * | 20     | 16             | amountMin                       |
     * | 36     | 20             | receiver                        |
     * | 56     | 20             | vault                           |
     */
    function _skimEulerV2Deposit(uint256 currentOffset) internal returns (uint256) {
        assembly {
            let underlying := shr(96, calldataload(currentOffset))
            // offset for amount at lower bytes
            let amountData := shr(128, calldataload(add(currentOffset, 20)))
            // receiver
            let receiver := shr(96, calldataload(add(currentOffset, 36)))

            let amountMin := and(UINT120_MASK, amountData)

            // get vault
            let vault := shr(96, calldataload(add(currentOffset, 56)))

            // selector for balanceOf(address)
            mstore(0, ERC20_BALANCE_OF)
            // add this address as parameter
            mstore(0x04, vault)
            // call to token
            pop(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20))
            // load the retrieved balance
            let vaultBalance := mload(0x0)

            // selector for balanceOf(address)
            mstore(0, CASH)
            // add this address as parameter
            mstore(0x04, vault)
            // call to token
            pop(staticcall(gas(), vault, 0x0, 0x4, 0x0, 0x20))
            // get accounted balance
            let vaultCash := mload(0x0)

            // check if enough is mintable
            //  if (balance <= cash || balance - cash < amountMin) revert SwapVerifier_skimMin();
            if or(not(gt(vaultBalance, vaultCash)), lt(sub(vaultBalance, vaultCash), amountMin)) {
                mstore(0x0, SLIPPAGE)
                revert(0x0, 0x4)
            }

            let ptr := mload(0x40)

            // selector skim(uint256,address)
            mstore(ptr, 0x8d56c63900000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), MAX_UINT256)
            mstore(add(ptr, 0x24), receiver)
            // call vault
            if iszero(call(gas(), vault, 0x0, ptr, 0x44, 0x0, 0x0)) {
                returndatacopy(0x0, 0x0, returndatasize())
                revert(0x0, returndatasize())
            }

            // skip vault (end of data)
            currentOffset := add(currentOffset, 76)
        }

        return currentOffset;
    }
}
