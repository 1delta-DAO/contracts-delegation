import {
    AAVE_FORK_POOL_DATA,
    AAVE_STYLE_RESERVE_ASSETS,
    AAVE_STYLE_TOKENS,
    ASSET_META,
    CHAIN_INFO,
    COMETS_PER_CHAIN_MAP,
    COMPOUND_BASE_TOKENS,
    COMPOUND_STYLE_RESERVE_ASSETS,
    COMPOUND_V2_COMPTROLLERS,
    COMPOUND_V2_STYLE_RESERVE_ASSETS,
    COMPOUND_V2_STYLE_TOKENS
} from "@1delta/asset-registry";
import { getAddress } from "ethers/lib/utils";
import * as fs from 'fs';
import { uniq } from "lodash";

const contractHeader = () => `
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

struct LenderTokens {
    address collateral;
    address debt;
    address stableDebt;
}


contract LenderRegistry {
    // chainId -> lender -> underlying -> data
    mapping(string =>  mapping(string => mapping(address => LenderTokens))) lendingTokens;
    mapping(string => mapping(string => address)) lendingControllers;
    // chainId -> lender -> baseAssets
    mapping(string => mapping(string => address)) cometToBase;

    // chain -> symbol -> address
    mapping(string => mapping(string => address)) tokens;
`

function getChainString(s: any) {
    return CHAIN_INFO[s].enum
}

const chainLibHeader = () => `

library Chains {

`


const tokenLibHeader = () => `

library Tokens {

`


const lenderLibHeader = () => `

library Lenders {

`

async function main() {
    let chainIdsCovered: any[] = []
    let lendersCovered: any[] = []

    // aave
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender,
        maps]) => {
        lendersCovered.push(lender)
        Object.entries(maps).forEach(([chains, _]) => {
            chainIdsCovered.push(chains)
        })
    })

    // compound V3
    Object.entries(COMETS_PER_CHAIN_MAP).forEach(([chain, maps]) => {
        chainIdsCovered.push(chain)
        Object.entries(maps).forEach(([lender, _]) => {
            lendersCovered.push(lender)
        })
    })


    // compound V2
    Object.entries(COMPOUND_V2_COMPTROLLERS).forEach(([lender, maps]) => {
        lendersCovered.push(lender)
        Object.entries(maps).forEach(([chains, _]) => {
            chainIdsCovered.push(chains)
        })
    })

    let data = contractHeader()
    let chainToToken: { [a: string]: string[] } = {}

    // begin constuctor
    data += `constructor() {\n`

    // AAVE DATA
    Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps]) => {
        const tokens = AAVE_STYLE_TOKENS[lender]

        // add aave tokens
        Object.entries(tokens).map(([chainId, tokens]) => {
            if (!chainToToken[chainId]) chainToToken[chainId] = []
            chainToToken[chainId] = [...chainToToken[chainId], ...AAVE_STYLE_RESERVE_ASSETS[lender][chainId]]
            Object.entries(tokens).map(([reserve, lenderTokens]) => {
                data += `lendingTokens["${getChainString(chainId)}"]["${lender}"][${getAddress(reserve)}] = LenderTokens(${getAddress(lenderTokens.aToken)},${getAddress(lenderTokens.vToken)},${getAddress(lenderTokens.sToken)});\n`
            })
        })
        // add pools
        Object.entries(maps).forEach(([chain, aaveInfoData]) => {
            data += `lendingControllers["${getChainString(chain)}"]["${lender}"] = ${getAddress(aaveInfoData.pool)};\n`
        })
    })

    // COMPOUND V3 DATA
    Object.entries(COMETS_PER_CHAIN_MAP).map(([chain, lenderToComet]) => {

        // add comets and controllers
        Object.entries(lenderToComet).map(([lender, comet]) => {
            if (!chainToToken[chain]) chainToToken[chain] = []
            chainToToken[chain] = [...chainToToken[chain], ...COMPOUND_STYLE_RESERVE_ASSETS[lender][chain]]
            data += `lendingControllers["${getChainString(chain)}"]["${lender}"] = ${getAddress(comet as any)};\n`
        })

    })
    // map comets to base
    Object.entries(COMPOUND_BASE_TOKENS).map(([lender, chainIdToBase]) => {
        Object.entries(chainIdToBase).map(([chainId, baseData]) => {
            data += `cometToBase["${getChainString(chainId)}"]["${lender}"] = ${getAddress(baseData.baseAsset)};\n`
        })
    })


    // COMPOUND V2 DATA
    Object.entries(COMPOUND_V2_COMPTROLLERS).forEach(([lender, maps]) => {
        const tokens = COMPOUND_V2_STYLE_TOKENS[lender]

        // add aave tokens
        Object.entries(tokens).map(([chainId, tokens]) => {
            if (!chainToToken[chainId]) chainToToken[chainId] = []
            chainToToken[chainId] = [...chainToToken[chainId], ...COMPOUND_V2_STYLE_RESERVE_ASSETS[lender][chainId]]
            Object.entries(tokens).map(([reserve, lenderTokens]) => {
                data += `lendingTokens["${getChainString(chainId)}"]["${lender}"][${getAddress(reserve)}] = LenderTokens(${getAddress(lenderTokens)}, address(0), address(0));\n`
            })
        })
        // add pools
        Object.entries(maps).forEach(([chain, comptroller]) => {
            data += `lendingControllers["${getChainString(chain)}"]["${lender}"] = ${getAddress(comptroller)};\n`
        })
    })



    let tokenData = ``
    let tokenSymbols: string[] = []
    // add token addresses
    Object.entries(chainToToken).forEach(([chain, tokenList]) => {
        const _tokenListClean = uniq(tokenList)
        _tokenListClean.map(token => {
            const meta = ASSET_META[chain]?.[token]
            // skip non-mapeeds for now
            if (meta && !meta.assetGroup?.endsWith(")")) {
                const key = symbolToKey(meta.symbol) ?? meta.symbol
                tokenSymbols.push(key)
                tokenData += `tokens["${getChainString(chain)}"]["${key}"] = ${getAddress(token)};\n`
            }
        })

    })

    data += tokenData

    // close constructor
    data += `}\n`

    // close contract part
    data += `}\n`


    // create chainId mapping library
    let libraryPart = chainLibHeader()
    uniq(chainIdsCovered).map(c => {
        libraryPart += `string internal constant ${getChainString(c)} = "${getChainString(c)}";\n`
    })
    libraryPart += `}\n`

    // add to file
    data += libraryPart

    // create token library
    let tokenPart = tokenLibHeader()
    uniq(tokenSymbols).map(a => {
        tokenPart += `string internal constant ${a} = "${a}";\n`
    })
    tokenPart += `}\n`

    // add to file
    data += tokenPart

    // create lender library
    let lenderLibPart = lenderLibHeader()
    uniq(lendersCovered).map(c => {
        lenderLibPart += `string internal constant ${c} = "${c}";\n`
    })
    lenderLibPart += `}\n`

    // add to file
    data += lenderLibPart

    const filePath = `./test/data/LenderRegistry.sol`
    fs.writeFileSync(filePath, data);
}

/** Copy-pasted from the registry to create valid enum names for assets */

/** Generate a valid enum key for an asset */
function symbolToKey(s: string) {
    let adjusted = s
    if (!isNaN(Number(adjusted[0]))) {
        const fl = adjusted[0]
        const word = numberToWords(Number(fl))
            .replaceAll(" ", "_")
            .toUpperCase()
        adjusted = word + "_" + adjusted.slice(1)
    }
    let symb = replacePlusSymbol(adjusted
        .replaceAll(" ", "_")
        .replaceAll("-", "_")
        .replaceAll(".", "_")
        .replaceAll("/", "")
        .toUpperCase())
    symb = mapSpecialSymbols(symb)

    if (isAlphaNumericOrDollar(symb)) return symb
    return undefined
}

// convert number to a word
function numberToWords(num: number) {
    if (num === 0) return "zero";
    const ones = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
    return ones[num]
}

function replacePlusSymbol(str: string) {
    // @ts-ignore
    return str.replace(/\++/, (match, offset, input) => {
        // Check if the match is at the end of the string
        if (offset === input.length - 1) {
            return '_PLUS_PLUS';
        }
        return '_PLUS_PLUS_';
        // @ts-ignore
    }).replace(/\+/, (match, offset, input) => {
        // Check if the match is at the end of the string
        if (offset === input.length - 1) {
            return '_PLUS';
        }
        return '_PLUS_';
    });
}
function isAlphaNumericOrDollar(str: string) {
    // Test the string with a regular expression that includes the "$" symbol
    return /^[a-zA-Z0-9$_]*$/.test(str);
}
function mapSpecialSymbols(s: string) {
    return s.replaceAll("!", "E").replaceAll("?", "Q")
}


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
