
import { ethers } from "hardhat";
import { CometLens__factory } from "../../types";
import { ARBITRUM_CONFIGS } from "../_utils/getGasConfig";
import { AAVE_FORK_POOL_DATA, AAVE_STYLE_RESERVE_ASSETS, AAVE_STYLE_TOKENS, ASSET_META, Chain, Lender } from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from 'fs';

const importSnippetReserves = (l: string, c: any) => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

struct AaveTokens {
    address aToken;
    address vToken;
    address sToken;
}

contract ${l}_DATA_${c} {
    mapping(address => AaveTokens) lendingTokens;

`

const constantAddress = (name: string, v: string) => `address internal constant ${name} = ${v};\n`

async function main() {
    const chainId = Chain.BASE
    const lender = Lender.AAVE_V3
    const header = importSnippetReserves(lender, chainId)

    const poolData = AAVE_FORK_POOL_DATA[lender][chainId]
    const reserves = AAVE_STYLE_RESERVE_ASSETS[lender][chainId]
    const tokens = AAVE_STYLE_TOKENS[lender][chainId]

    console.log("tokens", tokens)
    let data = header
    data += `constructor() {\n`
    Object.entries(tokens).map(([reserves, tokens]) => {
        data +=`lendingTokens[${getAddress(reserves)}] = AaveTokens(${getAddress(tokens.aToken)},${getAddress(tokens.vToken)},${getAddress(tokens.sToken)});\n`
    })

    data += `}\n`

    data += constantAddress(lender + "_POOL", getAddress(poolData.pool))

    reserves.map(r => {
        data += constantAddress(ASSET_META[chainId][r].symbol, getAddress(r))
    })





    data += `}`

    const filePath = `./test/base/${lender}_DATA_${chainId}.sol`
    fs.writeFileSync(filePath, data);
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
