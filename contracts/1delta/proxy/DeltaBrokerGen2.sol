// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * \
 * Author: Achthar <achim@1delta.io>
 * /*****************************************************************************
 */
import {LibModules} from "./libraries/LibModules.sol";
import {IModuleConfig} from "./interfaces/IModuleConfig.sol";

contract DeltaBrokerProxyGen2 {
    error NoImplementation();

    // [LibModules.moduleStorage().selectorToModule].slot
    bytes32 private constant IMPLS_SLOT = 0x76a4e0db4b1954ed8d81a6d47b0f62dd8c71c2f4e57cbbe90dd863575a2bc402;

    constructor(address _contractOwner, address _moduleConfig) {
        LibModules.setContractOwner(_contractOwner);

        // Add the moduleConfig external function from the moduleConfigModule
        IModuleConfig.ModuleConfig[] memory cut = new IModuleConfig.ModuleConfig[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IModuleConfig.configureModules.selector;
        cut[0] = IModuleConfig.ModuleConfig({
            moduleAddress: _moduleConfig,
            action: IModuleConfig.ModuleConfigAction.Add,
            functionSelectors: functionSelectors
        });
        LibModules.configureModules(cut);
    }

    // Find module for function that is called and execute the
    // function if a module is found and return any value.
    fallback() external payable {
        assembly {
            let cdlen := calldatasize()
            // Store at 0x40, to leave 0x00-0x3F for slot calculation below.
            calldatacopy(0x40, 0x00, cdlen)
            let target := and(mload(0x40), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)

            // Slot for impls[target] is keccak256(target . IMPLS_SLOT).
            mstore(0x00, target)
            mstore(0x20, IMPLS_SLOT)
            let slot := keccak256(0x00, 0x40)
            target := sload(slot) // overwrite target to delegate address
            if iszero(target) {
                // Revert with:
                // abi.encodeWithSelector(
                //   bytes4(keccak256("NoImplementation()")))
                mstore(0x00, 0xc6745ca800000000000000000000000000000000000000000000000000000000)
                revert(0x00, 4)
            }

            let success := delegatecall(gas(), target, 0x40, cdlen, 0x00, 0x00)
            let rdlen := returndatasize()
            returndatacopy(0x00, 0x00, rdlen)
            if success { return(0x00, rdlen) }
            revert(0x00, rdlen)
        }
    }

    receive() external payable {}
}
