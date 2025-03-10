// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../shared/errors/Errors.sol";

/**
 * @title Universal aggregator contract.
 *        Allows spot and margin swap aggregation
 *        Efficient baching through compact calldata usage.
 * @author 1delta Labs AG
 */
contract MorphoFlashLoanCallback is Masks, DeltaErrors {
    /// @dev Constant MorphoB address
    address private constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    /** Morpho blue callbacks */

    /// @dev Morpho Blue flash loan
    function onMorphoFlashLoan(uint256 amount, bytes calldata params) external {
        _onMorphoCallback(amount, params);
    }

    /// @dev Morpho Blue supply callback
    function onMorphoSupply(uint256 amount, bytes calldata params) external {
        _onMorphoCallback(amount, params);
    }

    /// @dev Morpho Blue repay callback
    function onMorphoRepay(uint256 amount, bytes calldata params) external {
        _onMorphoCallback(amount, params);
    }

    /// @dev Morpho Blue supply collateral callback
    function onMorphoSupplyCollateral(uint256 amount, bytes calldata params) external {
        _onMorphoCallback(amount, params);
    }

    /// @dev Morpho Blue is immutable and their flash loans are callbacks to msg.sender,
    /// Since it is universal batching and the same validation for all
    /// Morpho callbacks, we can use the same logic everywhere
    function _onMorphoCallback(uint256 amount, bytes calldata params) internal {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length
            // we expect at least an address
            // and a sourceId (uint8)
            // invalid params will lead to errors in the
            // compose at the bottom
            if lt(calldataLength, 21) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }

            // Validate the caller - MUST be morpho
            if xor(caller(), MORPHO_BLUE) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the `origCaller`
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, calldataload(100))
            // shift / slice params
            calldataLength := sub(calldataLength, 20)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(origCaller, amount, amount, 120, calldataLength);
    }

    function _deltaComposeInternal(address callerAddress, uint256 paramPull, uint256 paramPush, uint256 offset, uint256 length) internal virtual {}
}
