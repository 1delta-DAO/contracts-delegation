// SPDX-License-Identifier: MIT
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
