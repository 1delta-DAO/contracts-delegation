// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from "./Ownable.sol";
import {Slots} from "../../shared/storage/Slots.sol";

/// @notice Simple whitelister
abstract contract Storage is Ownable, Slots {
    /**
     * Whitelist a call target - typiclally DEX aggregators
     * Do NOT whitelist tokens or lenders!
     * @param callTarget target that callable in _extCall
     * @param value true if callahle, false if not
     */
    function whitelistCallTarget(address callTarget, bool value) external onlyOwner {
        assembly {
            // get slot isValid[target]
            mstore(0x0, callTarget)
            mstore(0x20, CALL_MANAGEMENT_VALID)
            let key := keccak256(0x0, 0x40)
            sstore(key, value)
        }
    }
}
