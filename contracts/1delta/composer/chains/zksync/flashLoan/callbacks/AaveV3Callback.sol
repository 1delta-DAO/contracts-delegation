// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Aave V3 flash loan callback (zkSync Era)
 * @dev Pool address is a placeholder — update with the actual zkSync Era Aave V3 Pool before deploy.
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    address private constant AAVE_V3_POOL = 0x78e30497a3c7527d953c6B1E3541b021A98Ac43c;

    function executeOperation(address, uint256, uint256, address initiator, bytes calldata params) external returns (bool) {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length

            let firstWord := calldataload(196)

            switch and(UINT8_MASK, shr(88, firstWord))
            case 0 {
                if xor(caller(), AAVE_V3_POOL) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            if xor(address(), initiator) {
                mstore(0, INVALID_INITIATOR)
                revert(0, 0x4)
            }
            origCaller := shr(96, firstWord)
            calldataLength := sub(calldataLength, 21)
        }
        _deltaComposeInternal(origCaller, 217, calldataLength);
        return true;
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
