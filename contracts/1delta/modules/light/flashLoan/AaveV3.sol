// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {ERC20Selectors} from "../../shared/selectors/ERC20Selectors.sol";
import {Masks} from "../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../shared/errors/Errors.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract AaveV3FlashLoans is ERC20Selectors, Masks, DeltaErrors {
    /*
     * | Offset | Length (bytes) | Description                     |
     * |--------|----------------|---------------------------------|
     * | 0      | 20             | asset                           |
     * | 20     | 20             | pool                            | <-- we allow ANY aave v2 style pool here
     * | 40     | 16             | amount                          |
     * | 56     | 2              | paramsLength                    |
     * | 58     | paramsLength   | params                          |
     */
    function aaveV3FlashLoan(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        assembly {
            // get token to loan
            let token := shr(96, calldataload(currentOffset))

            // target to call
            let pool := shr(96, calldataload(add(currentOffset, 20)))

            // second calldata slice including amount annd params length
            let slice := calldataload(add(currentOffset, 40))
            let amount := shr(128, slice) // shr will already mask uint112 here
            // length of params
            let calldataLength := and(UINT16_MASK, shr(112, slice))

            // skip addresses and amount
            currentOffset := add(currentOffset, 58)

            let ptr := mload(0x40)
            // flashLoanSimple(...)
            mstore(ptr, 0x42b0b77c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            mstore(add(ptr, 36), token) // asset
            mstore(add(ptr, 68), amount) // amount
            mstore(add(ptr, 100), 0xa0) // offset calldata
            mstore(add(ptr, 132), 0) // refCode
            mstore(add(ptr, 164), add(20, calldataLength)) // length calldata
            // caller at the beginning
            mstore(add(ptr, 196), shl(96, callerAddress))
            calldatacopy(add(ptr, 216), currentOffset, calldataLength) // calldata
            if iszero(
                call(
                    gas(),
                    pool,
                    0x0,
                    ptr,
                    add(calldataLength, 216), // = 7 * 32 + 4
                    0x0,
                    0x0 //
                )
            ) {
                let rdlen := returndatasize()
                returndatacopy(0, 0, rdlen)
                revert(0x0, rdlen)
            }

            // increment offset
            currentOffset := add(currentOffset, calldataLength)
        }
        return currentOffset;
    }
}
