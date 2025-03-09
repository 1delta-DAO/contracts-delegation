import { ASSET_META, Chain, COMPOUND_BASE_TOKENS, COMPOUND_V2_COMPTROLLERS, COMPOUND_V2_STYLE_RESERVE_ASSETS, COMPOUND_V2_STYLE_TOKENS, Lender } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from 'fs';

const importSnippetReserves = (l: string, c: any) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

contract ${l}_DATA_${c} {
`

const constantAddress = (name: string, v: string) => `address internal constant ${name} = ${v};\n`

async function main() {
    const chainId = Chain.ARBITRUM_ONE
    const header = importSnippetReserves("COMPOUND_V2", chainId)

    let data = header

    const forks = Object.keys(COMPOUND_V2_COMPTROLLERS)

    forks.map(f => {
        data += `mapping(address => address) ${f}_cTokens;\n`
    })

    let constructorSnippet = `constructor() {\n`

    let allReserves: any = {}
    forks.map(lender => {

        const ctokens = COMPOUND_V2_STYLE_TOKENS[lender][chainId]
        const reserves = COMPOUND_V2_STYLE_RESERVE_ASSETS[lender][chainId]

        data += constantAddress(lender + "_COMPTROLLER", getAddress(COMPOUND_V2_COMPTROLLERS[lender][chainId]))

        reserves.map(r => {
            const symbol = ASSET_META[chainId][r]?.symbol
            if (symbol) allReserves[symbol] = { address: r, name: symbol }
        })

        reserves.map(r =>
            constructorSnippet += `${lender}_cTokens[${getAddress(r)}] = ${getAddress(ctokens[r])};\n`
        )
    })
    constructorSnippet += `}\n`


    data += constructorSnippet

    Object.entries(allReserves).map(([a, c]) => { // @ts-ignore
        data += constantAddress(a, getAddress(c.address))
    })


    data += `}`

    const filePath = `./test/base/COMPOUND_V2_DATA_${chainId}.sol`
    fs.writeFileSync(filePath, data);
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
