// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {StargateV2} from "./StargateV2/StargateV2.sol";
import {Across} from "./Across/Across.sol";
import {SquidRouter} from "./Squid_Router/SquidRouter.sol";
import {GasZip} from "./GasZip/GasZip.sol";
import {BridgeIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";

/**
 * @notice Aggregates multiple bridge calls
 */
contract BridgeForwarder is StargateV2, Across, SquidRouter, GasZip {
    /**
     * @notice Routes to appropriate bridge operation based on operation ID
     * @dev Supports Stargate V2, Across, SquidRouter, and GasZip bridges
     * @param currentOffset Current position in the calldata
     * @return Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description     |
     * |--------|----------------|-----------------|
     * | 0      | 1              | bridgeOperation  |
     */
    function _bridge(uint256 currentOffset) internal returns (uint256) {
        uint256 bridgeOperation;
        assembly {
            let firstSlice := calldataload(currentOffset)
            bridgeOperation := shr(248, firstSlice)
            currentOffset := add(currentOffset, 1)
        }
        if (bridgeOperation == BridgeIds.STARGATE_V2) {
            return _bridgeStargateV2(currentOffset);
        } else if (bridgeOperation == BridgeIds.ACROSS) {
            return _bridgeAcross(currentOffset);
        } else if (bridgeOperation == BridgeIds.SQUID_ROUTER) {
            return _bridgeSquidRouter(currentOffset);
        } else if (bridgeOperation == BridgeIds.GASZIP) {
            return _bridgeGasZip(currentOffset);
        } else {
            _invalidOperation();
        }
    }
}
