// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IModuleConfig} from "../interfaces/IModuleConfig.sol";
import {LibModules} from "../libraries/LibModules.sol";

// solhint-disable max-line-length

contract ConfigModule is IModuleConfig {
    /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _moduleConfig Contains the facet addresses and function selectors
    function configureModules(ModuleConfig[] calldata _moduleConfig) external override {
        LibModules.enforceIsContractOwner();
        LibModules.configureModules(_moduleConfig);
    }
}
