

export const templateFlahLoan = (
    hasAaveV2: boolean,
    hasAaveV3: boolean,
    hasMorpho: boolean,
    hasBalancerV2: boolean
) => {
    let cbs: { imports: string, name: string }[] = []

    if (hasAaveV2) {
        cbs.push({
            imports: `import {AaveV2FlashLoanCallback} from "./AaveV2Callback.sol";`,
            name: "AaveV2FlashLoanCallback"
        })
    }


    if (hasAaveV3) {
        cbs.push({
            imports: `import {AaveV3FlashLoanCallback} from "./AaveV3Callback.sol";`,
            name: "AaveV3FlashLoanCallback"
        })
    }


    if (hasMorpho) {
        cbs.push({
            imports: `import {MorphoFlashLoanCallback} from "./MorphoCallback.sol";`,
            name: "MorphoFlashLoanCallback"
        })
    }


    if (hasBalancerV2) {
        cbs.push({
            imports: `import {BalancerV2FlashLoanCallback} from "./BalancerV2Callback.sol";`,
            name: "BalancerV2FlashLoanCallback"
        })
    }

    if(cbs.length ===0) throw new Error("No Flash loans")

    return `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

${cbs.map(a => a.imports + `\n`).join("")}


/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks is
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
            ${cbs.map(a => a.name).join(",\n") + "//"}
        )
    {}
}

`}