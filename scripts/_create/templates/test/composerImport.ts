import {chains} from "@1delta/data-sdk";
import {getChainKey, toCamelCaseWithFirstUpper} from "../../config";

export const composerTestImports = (chainsList: string[]) => {
    let imports: string[] = [];
    let ifelses: string[] = [];

    chainsList.forEach((chain) => {
        const chainKey = getChainKey(chain);
        const composerName = `OneDeltaComposer${toCamelCaseWithFirstUpper(chainKey)}`;
        imports.push(`import {${composerName}} from "../../../contracts/1delta/composer//chains/${chainKey}/Composer.sol";`);
        ifelses.push(
            `if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.${
                chains()[chain].enum //
            }))) return IComposerLike(address(new ${composerName}()));`
        );
    });

    return `
// SPDX-License-Identifier: NONE
pragma solidity ^0.8.28;
import {IComposerLike} from "./IComposerLike.sol";
import {Chains} from "../../data/LenderRegistry.sol";
${imports.join("\n")}

library ComposerPlugin {
    function getComposer(string memory chainName) public returns (IComposerLike) {
        ${ifelses.join("\n")}

        revert("No composer for chain");
    }
}
`;
};
