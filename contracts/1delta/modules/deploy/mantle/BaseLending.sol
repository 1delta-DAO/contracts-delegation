// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

import {WithStorage} from "../../../storage/BrokerStorage.sol";

// solhint-disable max-line-length

/**
 * @title Any Uniswap Callback Base contract
 * @notice Contains main logic for uniswap callbacks
 */
abstract contract BaseLending is WithStorage {
    uint256 private constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant UINT8_MASK_UPPER = 0xff00000000000000000000000000000000000000000000000000000000000000;

    /// @notice Withdraw from lender given user address and lender Id from cache
    function withdraw(address _underlying, address _to, uint256 _amount) internal {
        mapping(bytes32 => address) storage collateralTokens = ls().collateralTokens;
        bytes32 cache = gcs().cache;
        assembly {
            // read user and lender from cache
            let user := and(cache, ADDRESS_MASK_UPPER)
            let _lenderId := shr(248, and(UINT8_MASK_UPPER, cache))
            // Slot for collateralTokens[target] is keccak256(target . collateralTokens.slot).
            mstore(0x0, _underlying)
            mstore8(0x0, _lenderId)
            mstore(0x20, collateralTokens.slot)
            let collateralToken := sload(keccak256(0x0, 0x40))

            // selector for transferFrom(address,address,uint256)
            mstore(0x0, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(0x04, user)
            mstore(0x24, address())
            mstore(0x44, _amount)

            let success := call(gas(), collateralToken, 0, 0x0, 0x64, 0x0, 32)

            let rdsize := returndatasize()

            // Check for ERC20 success. ERC20 tokens should return a boolean,
            // but some don't. We accept 0-length return data as success, or at
            // least 32 bytes that starts with a 32-byte boolean true.
            success := and(
                success, // call itself succeeded
                or(
                    iszero(rdsize), // no return data, or
                    and(
                        iszero(lt(rdsize, 32)), // at least 32 bytes
                        eq(mload(0x0), 1) // starts with uint256(1)
                    )
                )
            )

            if iszero(success) {
                returndatacopy(0x0, 0, rdsize)
                revert(0x0, rdsize)
            }
            // selector withdraw(address,uint256,address)
            mstore(0x0, 0x5b88eb3100000000000000000000000000000000000000000000000000000000)
            mstore(0x4, _underlying)
            mstore(0x24, _amount)
            mstore(0x44, _to)
            let pool
            // assign lending pool
            switch _lenderId
            case 0 {
                pool := 0x0
            }
            default {
                pool := 0x0
            }
            // call pool
            success := call(gas(), pool, 0, 0x0, 0x64, 0x0, 0x0)
            if iszero(success) {
                rdsize := returndatasize()
                returndatacopy(0x0, 0, rdsize)
                revert(0x0, rdsize)
            }
        }
    }
}
