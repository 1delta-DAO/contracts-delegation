// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title All Morpho Blue flash callbacks
 */
contract MorphoFlashLoanCallback is Masks, DeltaErrors {
    /// @dev Constant MorphoB address
    address private constant MORPHO_BLUE = 0x1bF0c2541F820E775182832f06c0B7Fc27A25f67;

    /**
     * Morpho blue callbacks
     */

    /// @dev Morpho Blue flash loan
    function onMorphoFlashLoan(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue supply callback
    function onMorphoSupply(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue repay callback
    function onMorphoRepay(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue supply collateral callback
    function onMorphoSupplyCollateral(uint256, bytes calldata params) external {
        _onMorphoCallback(params);
    }

    /// @dev Morpho Blue is immutable and their flash loans are callbacks to msg.sender,
    /// Since it is universal batching and the same validation for all
    /// Morpho callbacks, we can use the same logic everywhere
    function _onMorphoCallback(bytes calldata params) internal {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(params.offset)
            if xor(caller(), MORPHO_BLUE) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginnig of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            120, // offset is constant
            calldataLength
        );
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
