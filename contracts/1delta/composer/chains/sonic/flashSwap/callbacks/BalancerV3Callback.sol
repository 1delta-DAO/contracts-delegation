// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Contract Module taking Balancer V3 callbacks
 */
abstract contract BalancerV3Callbacks is Masks, DeltaErrors {
    // v3 vault addresses
    address private constant BALANCER_V3 = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    /**
     * @notice Callback from Balancer V3 type vaults
     * @dev Note that this selector is a custom choice
     
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 4              | selector                     |
     * | 4      | 32             | offset                       |
     * | 36     | 32             | length                       |
     * | 68     | 20             | callerAddress                |
     * | 88     | 1              | poolId                       |
     * | 89     | Variable       | composeOperations            |
     */
    function balancerUnlockCallback(bytes calldata) external {
        address callerAddress;
        uint256 length;
        assembly {
            // callerAddress populates the first 20 bytes
            callerAddress := shr(96, calldataload(68))

            // cut off address and poolId
            length := sub(calldataload(36), 21)

            /**
             * Ensure that the caller is the singleton of choice
             */
            if xor(caller(), BALANCER_V3) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
        /**
         * This is to execute swaps or flash loans
         * For swaps, one needs to bump the composer swap command in here
         * For Flash loan, the composer commands for take, sync and settle
         * have to be executed
         */
        _deltaComposeInternal(
            callerAddress,
            89, // natural offset is 68 plus selector plus addres plus poolId
            length //
        );
    }

    /**
     * @notice Internal function to execute compose operations
     * @dev A composer contract should override this
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
