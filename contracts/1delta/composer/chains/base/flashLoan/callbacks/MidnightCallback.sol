// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Morpho Midnight flash-loan callback
 * @notice Handles `onFlashLoan(address,address[],uint256[],bytes)` for the canonical Midnight instance.
 * @dev Midnight sends the borrowed tokens to this composer, invokes this callback, then pulls each amount
 *      back via `transferFrom(this, ...)` - the compose operations executed here must repay + approve
 *      Midnight for every borrowed token. The callback must return `CALLBACK_SUCCESS` or Midnight reverts.
 */
contract MidnightFlashLoanCallback is Masks, DeltaErrors {
    /// @dev Canonical Morpho Midnight instance
    address private constant MIDNIGHT = 0xAdedD8ab6dE832766Fedf0FaC4992E5C4D3EA18A;

    /// @dev CALLBACK_SUCCESS = keccak256("morpho.midnight.callbackSuccess")
    bytes32 private constant CALLBACK_SUCCESS = 0x7f87788ea698181ea4d28d1576d0ba4fc92c0dbe5bf75b43692af2ce91dbaea2;

    /**
     * @notice Handles the Morpho Midnight flash-loan callback.
     * @dev The echoed `data` is `origCaller (20) | poolId (1) | composeOperations`. `poolId == 0` selects
     *      the canonical Midnight instance validated against `caller()`.
     */
    function onFlashLoan(
        address, // initiator (validated == address(this) in assembly below)
        address[] calldata, // tokens
        uint256[] calldata, // assets
        bytes calldata // data (validated + sliced in assembly below)
    )
        external
        returns (bytes32)
    {
        address origCaller;
        uint256 calldataLength;
        uint256 composeOffset;
        assembly {
            // `data` is the 4th (dynamic) argument; its offset (relative to the args block at 0x04) is the
            // head word at calldata 0x64. Two dynamic arrays precede it, so the position is not constant.
            let dataLenPos := add(0x04, calldataload(0x64))
            let dataLength := calldataload(dataLenPos)
            let dataStart := add(dataLenPos, 0x20)
            let firstWord := calldataload(dataStart)
            // validate caller: poolId 0 => canonical Midnight; anything else is unsupported

            switch and(UINT8_MASK, shr(88, firstWord))
            case 0 {
                if xor(caller(), MIDNIGHT) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // Require self-initiation. Midnight lets the CALLER choose the callback target (unlike
            // Morpho, which only ever calls back msg.sender), so `caller() == MIDNIGHT` alone does
            // NOT prove this composer initiated the loan. Without this check anyone could call
            // Midnight directly with `callback = this` and a spoofed origCaller, then execute compose
            // operations as an arbitrary victim. The initiator (== msg.sender of the flashLoan call)
            // is the first ABI argument at calldata 0x04.
            if xor(address(), and(ADDRESS_MASK, calldataload(0x04))) {
                mstore(0, INVALID_INITIATOR)
                revert(0, 0x4)
            }
            // slice the trusted origCaller (attached by the flash-loan initiator) off the data
            origCaller := shr(96, firstWord)
            calldataLength := sub(dataLength, 21)
            composeOffset := add(dataStart, 21)
        }
        // within the flash loan, any compose operation can be executed
        _deltaComposeInternal(origCaller, composeOffset, calldataLength);

        return CALLBACK_SUCCESS;
    }

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
