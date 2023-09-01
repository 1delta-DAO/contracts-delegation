// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Achthar <achim@1delta.io>
*
* Implementation of the 1Delta brokerage proxy.
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

    // An efficient multicall implementation for delegatecalls across multiple modules
    // The modules are validated before anything is called.
    function multicallMultiModule(address[] calldata modules, bytes[] calldata data) external payable {
        LibModules.ModuleStorage storage ds;
        bytes32 position = LibModules.MODULE_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }

        for (uint256 i = 0; i != data.length; i++) {
            // we verify that the module exists
            address moduleAddress = modules[i];
            require(ds.moduleExists[moduleAddress], "Broker: Invalid module");
            (bool success, bytes memory result) = moduleAddress.delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
        }
    }

    // An efficient multicall implementation for delegatecalls on a single module
    // The single module is validated and then the delegatecalls are executed.
    function multicallSingleModule(address module, bytes[] calldata data) external payable {
        address moduleAddress = module;

        LibModules.ModuleStorage storage ds;
        bytes32 position = LibModules.MODULE_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }

        // important check that the input is in fact an implementation by 1DeltaDAO
        require(ds.moduleExists[moduleAddress], "Broker: Invalid module");
        for (uint256 i = 0; i != data.length; i++) {
            (bool success, bytes memory result) = moduleAddress.delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }
        }
    }

    // Find module for function that is called and execute the
    // function if a module is found and return any value.
    fallback() external payable {
        LibModules.ModuleStorage storage ds;
        bytes32 position = LibModules.MODULE_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get module from function selector
        address module = ds.selectorToModule[msg.sig];
        require(module != address(0), "Broker: Function does not exist");
        // Execute external function from module using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the module
            let result := delegatecall(gas(), module, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    receive() external payable {}
}
