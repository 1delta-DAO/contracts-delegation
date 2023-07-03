// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LibModules} from "../libraries/LibModules.sol";
import {IModuleLens} from "../interfaces/IModuleLens.sol";
import {IERC165} from "../interfaces/IERC165.sol";

// solhint-disable max-line-length

contract LensModule is IModuleLens, IERC165 {
    // Diamond Loupe Functions
    ////////////////////////////////////////////////////////////////////
    /// These functions are expected to be called frequently by tools.
    //
    // struct Facet {
    //     address moduleAddress;
    //     bytes4[] functionSelectors;
    // }

    /// @notice Gets all modules and their selectors.
    /// @return modules_ Facet
    function modules() external view override returns (Module[] memory modules_) {
        LibModules.ModuleStorage storage ds = LibModules.moduleStorage();
        uint256 numFacets = ds.moduleAddresses.length;
        modules_ = new Module[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address moduleAddress_ = ds.moduleAddresses[i];
            modules_[i].moduleAddress = moduleAddress_;
            modules_[i].functionSelectors = ds.moduleFunctionSelectors[moduleAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a module.
    /// @param _module The module address.
    /// @return moduleFunctionSelectors_
    function moduleFunctionSelectors(address _module) external view override returns (bytes4[] memory moduleFunctionSelectors_) {
        LibModules.ModuleStorage storage ds = LibModules.moduleStorage();
        moduleFunctionSelectors_ = ds.moduleFunctionSelectors[_module].functionSelectors;
    }

    /// @notice Get all the module addresses used by a diamond.
    /// @return moduleAddresses_
    function moduleAddresses() external view override returns (address[] memory moduleAddresses_) {
        LibModules.ModuleStorage storage ds = LibModules.moduleStorage();
        moduleAddresses_ = ds.moduleAddresses;
    }

    /// @notice Gets the module that supports the given selector.
    /// @dev If module is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return moduleAddress_ The module address.
    function moduleAddress(bytes4 _functionSelector) external view override returns (address moduleAddress_) {
        LibModules.ModuleStorage storage ds = LibModules.moduleStorage();
        moduleAddress_ = ds.selectorToModuleAndPosition[_functionSelector].moduleAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        LibModules.ModuleStorage storage ds = LibModules.moduleStorage();
        return ds.supportedInterfaces[_interfaceId];
    }
}
