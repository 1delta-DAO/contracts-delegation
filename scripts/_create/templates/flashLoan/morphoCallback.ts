
export const templateMorphoBlue = (addressContants: string, switchCaseContent: string) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title All Morpho Blue flash callbacks
 */
contract MorphoFlashLoanCallback is Masks, DeltaErrors {
    /// @dev Constant MorphoB address
    ${addressContants}
    /** Morpho blue callbacks */

    /// @dev Morpho Blue flash loan
    function onMorphoFlashLoan(uint256, bytes calldata) external {
        _onMorphoCallback();
    }

    /// @dev Morpho Blue supply callback
    function onMorphoSupply(uint256, bytes calldata) external {
        _onMorphoCallback();
    }

    /// @dev Morpho Blue repay callback
    function onMorphoRepay(uint256, bytes calldata) external {
        _onMorphoCallback();
    }

    /// @dev Morpho Blue supply collateral callback
    function onMorphoSupplyCollateral(uint256, bytes calldata) external {
        _onMorphoCallback();
    }

    /// @dev Morpho Blue is immutable and their flash loans are callbacks to msg.sender,
    /// Since it is universal batching and the same validation for all
    /// Morpho callbacks, we can use the same logic everywhere
    function _onMorphoCallback() internal {
        address origCaller;
        uint256 calldataLength;
        assembly {
            // validate caller
            // - extract id from params
            let firstWord := calldataload(100)
            ${switchCaseContent}
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataLength := sub(calldataload(68), 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            121, // offset is constant (100 native + 21)
            calldataLength
        );
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
`
