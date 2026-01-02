export const templateFlashLoan = (hasAaveV2: boolean, hasAaveV3: boolean, hasMorpho: boolean, hasBalancerV2: boolean, hasLista = false) => {
    let cbs: {imports: string; name: string}[] = [];

    if (hasAaveV2) {
        cbs.push({
            imports: `import {AaveV2FlashLoanCallback} from "./callbacks/AaveV2Callback.sol";`,
            name: "AaveV2FlashLoanCallback",
        });
    }

    if (hasAaveV3) {
        cbs.push({
            imports: `import {AaveV3FlashLoanCallback} from "./callbacks/AaveV3Callback.sol";`,
            name: "AaveV3FlashLoanCallback",
        });
    }

    if (hasLista) {
        cbs.push({
            imports: `import {MoolahFlashLoanCallback} from "./callbacks/MoolahCallback.sol";`,
            name: "MoolahFlashLoanCallback",
        });
    }

    if (hasMorpho) {
        cbs.push({
            imports: `import {MorphoFlashLoanCallback} from "./callbacks/MorphoCallback.sol";`,
            name: "MorphoFlashLoanCallback",
        });
    }

    if (hasBalancerV2) {
        cbs.push({
            imports: `import {BalancerV2FlashLoanCallback} from "./callbacks/BalancerV2Callback.sol";`,
            name: "BalancerV2FlashLoanCallback",
        });
    }

    // if (cbs.length === 0) throw new Error("No Flash loans")

    return `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

${cbs.map((a) => a.imports + `\n`).join("")}


/**
 * @title Flash loan callbacks - these are chain-specific
 * @author 1delta Labs AG
 */
contract FlashLoanCallbacks ${cbs.length === 0 ? "" : "is"}
${cbs.map((a) => a.name).join(",\n") + "//"}
{
    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(
        address callerAddress,
        uint256 offset,
        uint256 length
    )
        internal
        virtual
        ${
            cbs.length === 0
                ? ""
                : `override(
            ${cbs.map((a) => a.name).join(",\n") + "//"}
        )`
        }
    {}
}

`;
};
