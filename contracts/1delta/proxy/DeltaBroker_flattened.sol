
// File: contracts/1delta/proxy/interfaces/IModuleConfig.sol


/**
 * Vendored on December 23, 2021 from:
 * https://github.com/mudgen/diamond-3-hardhat/blob/7feb995/contracts/interfaces/IModuleConfig.sol
 */
pragma solidity ^0.8.0;

interface IModuleConfig {
    enum ModuleConfigAction {
        Add,
        Replace,
        Remove
    }
    // Add=0, Replace=1, Remove=2

    struct ModuleConfig {
        address moduleAddress;
        ModuleConfigAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _moduleConfig Contains the module addresses and function selectors
    function configureModules(ModuleConfig[] calldata _moduleConfig) external;
}

// File: contracts/1delta/proxy/libraries/LibModules.sol



pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Achthar - 1delta.io
* Modified diamond module handling library
/******************************************************************************/


// solhint-disable max-line-length

error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

library LibModules {
    bytes32 constant MODULE_STORAGE_POSITION = keccak256("diamond.standard.module.storage");

    struct ModuleAddressAndPosition {
        address moduleAddress;
        uint96 functionSelectorPosition; // position in moduleFunctionSelectors.functionSelectors array
    }

    struct ModuleFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 moduleAddressPosition; // position of moduleAddress in moduleAddresses array
    }

    struct ModuleStorage {
        // maps function selector to the module address and
        // the position of the selector in the moduleFunctionSelectors.selectors array
        mapping(bytes4 => ModuleAddressAndPosition) selectorToModuleAndPosition;
        // maps selector to module
        mapping(bytes4 => address) selectorToModule;
        // maps module addresses to function selectors
        mapping(address => ModuleFunctionSelectors) moduleFunctionSelectors;
        // module addresses
        address[] moduleAddresses;
        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;
        // Used to query if a module exits
        mapping(address => bool) moduleExists;
        // owner of the contract
        address contractOwner;
    }

    function moduleStorage() internal pure returns (ModuleStorage storage ds) {
        bytes32 position = MODULE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setContractOwner(address _newOwner) internal {
        ModuleStorage storage ds = moduleStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = moduleStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        require(msg.sender == moduleStorage().contractOwner, "LibModuleConfig: Must be contract owner");
    }

    event Upgrade(IModuleConfig.ModuleConfig[] _moduleChange);

    // Internal function version of diamondCut
    function configureModules(IModuleConfig.ModuleConfig[] memory _moduleChange) internal {
        for (uint256 moduleIndex; moduleIndex < _moduleChange.length; moduleIndex++) {
            IModuleConfig.ModuleConfigAction action = _moduleChange[moduleIndex].action;
            if (action == IModuleConfig.ModuleConfigAction.Add) {
                addFunctions(_moduleChange[moduleIndex].moduleAddress, _moduleChange[moduleIndex].functionSelectors);
            } else if (action == IModuleConfig.ModuleConfigAction.Replace) {
                replaceFunctions(_moduleChange[moduleIndex].moduleAddress, _moduleChange[moduleIndex].functionSelectors);
            } else if (action == IModuleConfig.ModuleConfigAction.Remove) {
                removeFunctions(_moduleChange[moduleIndex].moduleAddress, _moduleChange[moduleIndex].functionSelectors);
            } else {
                revert("LibModuleConfig: Incorrect ModuleConfigAction");
            }
        }
        emit Upgrade(_moduleChange);
    }

    function addFunctions(address _moduleAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibModuleConfig: No selectors in module to cut");
        ModuleStorage storage ds = moduleStorage();
        require(_moduleAddress != address(0), "LibModuleConfig: Add module can't be address(0)");
        uint96 selectorPosition = uint96(ds.moduleFunctionSelectors[_moduleAddress].functionSelectors.length);
        // add new module address if it does not exist
        if (selectorPosition == 0) {
            addModule(ds, _moduleAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldModuleAddress = ds.selectorToModuleAndPosition[selector].moduleAddress;
            require(oldModuleAddress == address(0), "LibModuleConfig: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _moduleAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _moduleAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibModuleConfig: No selectors in module to cut");
        ModuleStorage storage ds = moduleStorage();
        require(_moduleAddress != address(0), "LibModuleConfig: Add module can't be address(0)");
        uint96 selectorPosition = uint96(ds.moduleFunctionSelectors[_moduleAddress].functionSelectors.length);
        // add new module address if it does not exist
        if (selectorPosition == 0) {
            addModule(ds, _moduleAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldModuleAddress = ds.selectorToModuleAndPosition[selector].moduleAddress;
            require(oldModuleAddress != _moduleAddress, "LibModuleConfig: Can't replace function with same function");
            removeFunction(ds, oldModuleAddress, selector);
            addFunction(ds, selector, selectorPosition, _moduleAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _moduleAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibModuleConfig: No selectors in module to cut");
        ModuleStorage storage ds = moduleStorage();
        // if function does not exist then do nothing and return
        require(_moduleAddress == address(0), "LibModuleConfig: Remove module address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldModuleAddress = ds.selectorToModuleAndPosition[selector].moduleAddress;
            removeFunction(ds, oldModuleAddress, selector);
        }
    }

    function addModule(ModuleStorage storage ds, address _moduleAddress) internal {
        enforceHasContractCode(_moduleAddress, "LibModuleConfig: New module has no code");
        ds.moduleFunctionSelectors[_moduleAddress].moduleAddressPosition = ds.moduleAddresses.length;
        ds.moduleAddresses.push(_moduleAddress);
        ds.moduleExists[_moduleAddress] = true;
    }

    function addFunction(
        ModuleStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _moduleAddress
    ) internal {
        ds.selectorToModuleAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.moduleFunctionSelectors[_moduleAddress].functionSelectors.push(_selector);
        ds.selectorToModuleAndPosition[_selector].moduleAddress = _moduleAddress;
        ds.selectorToModule[_selector] = _moduleAddress;
    }

    function removeFunction(
        ModuleStorage storage ds,
        address _moduleAddress,
        bytes4 _selector
    ) internal {
        require(_moduleAddress != address(0), "LibModuleConfig: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_moduleAddress != address(this), "LibModuleConfig: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToModuleAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.moduleFunctionSelectors[_moduleAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.moduleFunctionSelectors[_moduleAddress].functionSelectors[lastSelectorPosition];
            ds.moduleFunctionSelectors[_moduleAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToModuleAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.moduleFunctionSelectors[_moduleAddress].functionSelectors.pop();
        delete ds.selectorToModuleAndPosition[_selector];
        delete ds.selectorToModule[_selector];

        // if no more selectors for module address then delete the module address
        if (lastSelectorPosition == 0) {
            // replace module address with last module address and delete last module address
            uint256 lastModuleAddressPosition = ds.moduleAddresses.length - 1;
            uint256 moduleAddressPosition = ds.moduleFunctionSelectors[_moduleAddress].moduleAddressPosition;
            if (moduleAddressPosition != lastModuleAddressPosition) {
                address lastModuleAddress = ds.moduleAddresses[lastModuleAddressPosition];
                ds.moduleAddresses[moduleAddressPosition] = lastModuleAddress;
                ds.moduleFunctionSelectors[lastModuleAddress].moduleAddressPosition = moduleAddressPosition;
            }
            ds.moduleAddresses.pop();
            delete ds.moduleFunctionSelectors[_moduleAddress].moduleAddressPosition;
            ds.moduleExists[_moduleAddress] = false;
        }
    }

    function initializeModuleConfig(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibModuleConfig: _init address has no code");
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // bubble up error
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}

// File: contracts/1delta/proxy/DeltaBroker.sol



pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Achthar <achim@1delta.io>
/******************************************************************************/



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
                returndatacopy(0, 0, len)
                // revert if not successful - do not return any values on success
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
