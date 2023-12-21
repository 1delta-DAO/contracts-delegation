// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Achthar <achim@1delta.io>
/******************************************************************************/

import {LibModules} from "./libraries/LibModules.sol";
import {IModuleConfig} from "./interfaces/IModuleConfig.sol";

contract DeltaBrokerProxy {
    error noImplementation();

    constructor(address _contractOwner, address _moduleConfigModule) payable {
        LibModules.setContractOwner(_contractOwner);

        // Add the moduleConfig external function from the moduleConfigModule
        IModuleConfig.ModuleConfig[] memory cut = new IModuleConfig.ModuleConfig[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IModuleConfig.configureModules.selector;
        cut[0] = IModuleConfig.ModuleConfig({
            moduleAddress: _moduleConfigModule,
            action: IModuleConfig.ModuleConfigAction.Add,
            functionSelectors: functionSelectors
        });
        LibModules.configureModules(cut);
    }

    // An efficient multicall implementation for directly calling functions across multiple modules
    function multicall(bytes[] calldata data) external payable {
        // This is used in assembly below as impls.slot.
        mapping(bytes4 => address) storage impls = LibModules.moduleStorage().selectorToModule;
        // loop throught the calls and execute
        for (uint256 i; i != data.length; ) {
            bytes calldata call = data[i];
            assembly {
                let len := call.length
                calldatacopy(0x40, call.offset, len) // copy calldata to 0x40
                let target := and(
                    mload(0x40), // calldata was copied to 0, we load the selector from there
                    0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
                )
                mstore(0, target)
                mstore(0x20, impls.slot)
                let slot := keccak256(0, 0x40)
                target := sload(slot)
                if iszero(target) {
                    // Reverting with NoImplementation
                    mstore(0, 0x6826a5a500000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
                let success := delegatecall(gas(), target, 0x40, len, 0, 0)
                len := returndatasize()
                // revert if not successful - do not return any values on success
                if iszero(success) {
                    returndatacopy(0, 0, len)
                    revert(0, len)
                }
                // increase loop index
                i := add(i, 1)
            }
        }
    }

    // Find module for function that is called and execute the
    // function if a module is found and return any value.
    fallback() external payable {
        // This is used in assembly below as impls.slot.
        mapping(bytes4 => address) storage impls = LibModules.moduleStorage().selectorToModule;

        assembly {
            let cdlen := calldatasize()
            // Store at 0x40, to leave 0x00-0x3F for slot calculation below.
            calldatacopy(0x40, 0, cdlen)
            let target := and(mload(0x40), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)

            // Slot for impls[target] is keccak256(target . impls.slot).
            mstore(0, target)
            mstore(0x20, impls.slot)
            let slot := keccak256(0, 0x40)
            target := sload(slot) // overwrite target to delegate address
            if iszero(target) {
                // Revert with:
                // abi.encodeWithSelector(
                //   bytes4(keccak256("NoImplementation()")))
                mstore(0, 0x6826a5a500000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            let success := delegatecall(gas(), target, 0x40, cdlen, 0, 0)
            let rdlen := returndatasize()
            returndatacopy(0, 0, rdlen)
            if success {
                return(0, rdlen)
            }
            revert(0, rdlen)
        }
    }

    receive() external payable {}
}
