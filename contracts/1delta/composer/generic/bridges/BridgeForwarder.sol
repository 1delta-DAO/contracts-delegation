// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StargateV2} from "./StargateV2/StargateV2.sol";
import {Across} from "./Across/Across.sol";
import {BridgeIds} from "contracts/1delta/composer/enums/ForwarderEnums.sol";

contract BridgeForwarder is StargateV2, Across {
    function _bridge(uint256 currentOffset, address callerAddress) internal returns (uint256) {
        uint256 bridgeOperation;
        assembly {
            let firstSlice := calldataload(currentOffset)
            bridgeOperation := shr(248, firstSlice)
            currentOffset := add(currentOffset, 1)
        }
        if (bridgeOperation == BridgeIds.STARGATE_V2) {
            return _bridgeStargateV2(currentOffset, callerAddress);
        } else if (bridgeOperation == BridgeIds.ACROSS) {
            return _bridgeAcross(currentOffset, callerAddress);
        } else {
            _invalidOperation();
        }
    }
}
