// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Achthar <achim@1delta.io>
/******************************************************************************/

import {LibModules} from "./libraries/LibModules.sol";
import {IModuleConfig} from "./interfaces/IModuleConfig.sol";

contract DeltaBrokerProxy {
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
        for (uint256 i = 0; i != data.length; ) {
            bytes calldata call = data[i];
            assembly {
                let selector := and(calldataload(call.offset), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
                mstore(0, selector)
                mstore(0x20, impls.slot)
                let slot := keccak256(0, 0x40)
                let delegate := sload(slot)
                if iszero(delegate) {
                    // Reverting with NoImplementation
                    mstore(0, 0x734e6e1c00000000000000000000000000000000000000000000000000000000)
                    mstore(4, selector)
                    revert(0, 0x24)
                }
                let len := call.length
                calldatacopy(0, call.offset, len)
                let success := delegatecall(gas(), delegate, 0, len, 0, 0)
                len := returndatasize()
                returndatacopy(0, 0, len)
                if iszero(success) {
                    revert(0, len)
                }
            }
            unchecked {
                i++;
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
            let selector := and(mload(0x40), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)

            // Slot for impls[selector] is keccak256(selector . impls.slot).
            mstore(0, selector)
            mstore(0x20, impls.slot)
            let slot := keccak256(0, 0x40)

            let delegate := sload(slot)
            if iszero(delegate) {
                // Revert with:
                // abi.encodeWithSelector(
                //   bytes4(keccak256("NoImplementation(bytes4)")),
                //   selector)
                mstore(0, 0x734e6e1c00000000000000000000000000000000000000000000000000000000)
                mstore(4, selector)
                revert(0, 0x24)
            }

            let success := delegatecall(gas(), delegate, 0x40, cdlen, 0, 0)
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
