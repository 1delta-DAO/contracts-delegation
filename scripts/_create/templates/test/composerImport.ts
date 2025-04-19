import { CHAIN_INFO } from "@1delta/asset-registry"
import { getChainKey, toCamelCaseWithFirstUpper } from "../../config"

export const composerTestImports = (chains: string[]) => {

    let imports:string[] = []
    let ifelses:string[] = []

    chains.forEach(chain => {
        const chainKey = getChainKey(chain)
        const composerName = `OneDeltaComposer${toCamelCaseWithFirstUpper(chainKey)}`
        imports.push(`import {${composerName}} from "../../../contracts/1delta/modules/light/chains/${chainKey}/Composer.sol";`)
        ifelses.push(`if (keccak256(bytes(chainName)) == keccak256(bytes(Chains.${CHAIN_INFO[chain].enum //
            }))) return IComposerLike(address(new ${composerName}()));`)
    })


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
`
}