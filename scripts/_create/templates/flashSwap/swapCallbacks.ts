

export const templateSwapCallbacks = (
    hasV4: boolean,
    hasV3: boolean,
    hasV2: boolean,
    hasDodo: boolean,
    hasBalancerV3: boolean,
) => {
    let cbs: { imports: string, name: string, overr: string }[] = []

    if (hasV4) {
        cbs.push({
            imports: `import {UniV4Callbacks} from "./UniV4Callback.sol";`,
            name: "UniV4Callbacks",
            overr: "UniV4Callbacks"
        })
    }

    if (hasV3) {
        cbs.push({
            imports: `import {UniV3Callbacks, V3Callbacker} from "./UniV3Callback.sol";`,
            name: "UniV3Callbacks",
            overr: "V3Callbacker"
        })
    }

    if (hasV2) {
        cbs.push({
            imports: `import {UniV2Callbacks} from "./UniV2Callback.sol";`,
            name: "UniV2Callbacks",
            overr: "UniV2Callbacks"
        })
    }

    if (hasDodo) {
        cbs.push({
            imports: `import {DodoV2Callbacks} from "./DodoV2Callback.sol";`,
            name: "DodoV2Callbacks",
            overr: "DodoV2Callbacks"
        })
    }

    if (hasBalancerV3) {
        cbs.push({
            imports: `import {BalancerV3Callbacks} from "./BalancerV3Callback.sol";`,
            name: "BalancerV3Callbacks",
            overr: "BalancerV3Callbacks"
        })
    }

    if (cbs.length === 0) throw new Error("No Flash loans")

    return `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

${cbs.map(a => a.imports + `\n`).join("")}
/**
 * @title Swap Callback executor
 * @author 1delta Labs AG
 */
contract SwapCallbacks is 
${cbs.map(a => a.name).join(",\n") + "//"}
{
    // override the compose
    function _deltaComposeInternal(
        address callerAddress,
        uint256 offset,
        uint256 length
    )
        internal
        virtual
        override(
            ${cbs.map(a => a.overr).join(",\n") + "//"}
        )
    {}

    /**
     * Swap callbacks are taken in the fallback
     * We do this to have an easier time in validating similar callbacks
     * with separate selectors
     *
     * We identify the selector in the fallback and then map it to the DEX
     *
     * Note that each "_execute..." function returns (exits) when a callback is run.
     *
     * If it falls through all variations, it reverts at the end.
     */
    fallback() external {
        bytes32 selector;
        assembly {
            selector := and(
                0xffffffff00000000000000000000000000000000000000000000000000000000, // masks upper 4 bytes
                calldataload(0)
            )
        }
        ${hasV3 ? "_executeUniV3IfSelector(selector);" : ""}
        ${hasV2 ? "_executeUniV2IfSelector(selector);" : ""}
        ${hasDodo ? "_executeDodoV2IfSelector(selector);" : ""}

        // we do not allow a fallthrough
        assembly {
            revert(0, 0)
        }
    }
}

`}