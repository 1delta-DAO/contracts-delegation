import { ASSET_META, Chain, COMETS_PER_CHAIN_MAP, COMPOUND_BASE_TOKENS, COMPOUND_STYLE_RESERVE_ASSETS, Lender } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from 'fs';

const importSnippetReserves = (l: string, c: any) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

contract ${l}_DATA_${c} {
    mapping(address => address) cometToBase;
`

const constantAddress = (name: string, v: string) => `address internal constant ${name} = ${v};\n`

async function main() {
    const chainId = Chain.BASE
    // const lender = Lender.COMPOUND_V3_USDC
    const header = importSnippetReserves("COMPOUND_V3", chainId)

    let data = header

    let constructorSnippet = `constructor() {\n`

    let allReserves: any = {}
    Object.entries(COMETS_PER_CHAIN_MAP[chainId]).map(([lender, comet]) => {

        const baseData = COMPOUND_BASE_TOKENS[lender][chainId]
        const reserves = COMPOUND_STYLE_RESERVE_ASSETS[lender][chainId]

        data += constantAddress(lender + "_BASE", getAddress(baseData.baseAsset))
        data += constantAddress(lender + "_COMET", getAddress(comet as any))



        reserves.map(r =>
            allReserves[ASSET_META[chainId][r].symbol] = { address: r, name: ASSET_META[chainId][r].symbol }
        )
        // reserves.map(r => {
        //     data += constantAddress(ASSET_META[chainId][r].symbol, getAddress(r))
        // })

        constructorSnippet += `cometToBase[${getAddress(comet as any)}] = ${getAddress(baseData.baseAsset)};\n`

    })
    constructorSnippet += `}\n`


    Object.entries(allReserves).map(([a, c]) => { // @ts-ignore
        data += constantAddress(a, getAddress(c.address))
    })


    data += `}`

    const filePath = `./test/base/COMPOUND_V3_DATA_${chainId}.sol`
    fs.writeFileSync(filePath, data);
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
