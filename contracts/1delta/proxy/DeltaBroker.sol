// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * \
 * Author: Achthar <achim@1delta.io>
 * /*****************************************************************************
 */
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
    // Note that this multicall is payable, as such, native multi-spending has to be taken into account by
    // the caller
    function multicall(bytes[] calldata data) external payable {
        // This is used in assembly below as impls.slot.
        mapping(bytes4 => address) storage impls = LibModules.moduleStorage().selectorToModule;
        assembly {
            mstore(0x00, 0x20)
            let tracker := 0x40
            // `shl` 5 is equivalent to multiplying by 0x20.
            let end := shl(5, data.length)
            // Copy the offsets from calldata into memory.
            calldatacopy(0x40, data.offset, end)
            // Offset into `tracker`.
            let currentOffset := end
            // Pointer to the end of `tracker`.
            end := add(tracker, end)

            for {} 1 {} {
                // The offset of the current bytes in the calldata.
                let o := add(data.offset, mload(tracker))
                let m := add(currentOffset, 0x40)
                // Copy the current bytes from calldata to the memory.
                calldatacopy(
                    m,
                    add(o, 0x20), // The offset of the current bytes' bytes.
                    calldataload(o) // The length of the current bytes.
                )
                // determine the selector
                let target :=
                    and(
                        mload(m), // calldata was copied to 0, we load the selector from there
                        0xFFFFFFFF00000000000000000000000000000000000000000000000000000000
                    )
                mstore(0x00, target)
                mstore(0x20, impls.slot)
                let slot := keccak256(0x00, 0x40)
                // assign module
                target := sload(slot)
                if iszero(target) {
                    // Reverting with NoImplementation
                    mstore(0x00, 0x6826a5a500000000000000000000000000000000000000000000000000000000)
                    revert(0x00, 4)
                }
                // execute the current call
                if iszero(delegatecall(gas(), target, m, calldataload(o), codesize(), 0x00)) {
                    // Bubble up the revert if the delegatecall reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                tracker := add(tracker, 0x20)
                if iszero(lt(tracker, end)) { break }
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
            calldatacopy(0x40, 0x00, cdlen)
            let target := and(mload(0x40), 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)

            // Slot for impls[target] is keccak256(target . impls.slot).
            mstore(0x00, target)
            mstore(0x20, impls.slot)
            let slot := keccak256(0x00, 0x40)
            target := sload(slot) // overwrite target to delegate address
            if iszero(target) {
                // Revert with:
                // abi.encodeWithSelector(
                //   bytes4(keccak256("NoImplementation()")))
                mstore(0x00, 0x6826a5a500000000000000000000000000000000000000000000000000000000)
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
