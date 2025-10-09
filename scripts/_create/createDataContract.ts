import {ASSET_META, CHAIN_INFO} from "@1delta/asset-registry";
import {
    aavePools,
    aaveReserves,
    aaveTokens,
    compoundV2Pools,
    compoundV2Reserves,
    compoundV2Tokens,
    compoundV3BaseData,
    compoundV3Pools,
    compoundV3Reserves,
    morphoPools,
} from "@1delta/data-sdk";
import {fetchLenderMetaFromDirAndInitialize} from "./utils";
import {getAddress} from "ethers/lib/utils";
import * as fs from "fs";
import {uniq} from "lodash";

const contractHeader = () => `
// SPDX-License-Identifier: BUSL-1.1
// solhint-disable max-line-length

pragma solidity ^0.8.28;

struct LenderTokens {
    address collateral;
    address debt;
    address stableDebt;
}

struct ChainInfo {
    string rpcUrl;
    uint256 chainId;
}

contract LenderRegistry {
    // chainId -> lender -> underlying -> data
    mapping(string =>  mapping(string => mapping(address => LenderTokens))) lendingTokens;
    mapping(string => mapping(string => address)) lendingControllers;
    // chainId -> lender -> baseAssets
    mapping(string => mapping(string => address)) cometToBase;

    // chain -> symbol -> address
    mapping(string => mapping(string => address)) tokens;
    
    // chain -> chain info (rpc, chainId, forkBlock)
    mapping(string => ChainInfo) chainInfo;
`;

const isAave = (arr: string[]) => {
    return `function  isAave(string memory lender) internal pure returns(bool isAaveFlag) {
  bytes32 _lender = keccak256(abi.encodePacked((lender))); 
  isAaveFlag = _lender == ${arr.map((a) => `keccak256(abi.encodePacked((${a})))`).join(" || _lender == ")};
  }`;
};

const isCompoundV3 = (arr: string[]) => {
    return `function  isCompoundV3(string memory lender) internal pure returns(bool isCompoundV3Flag) {
    bytes32 _lender = keccak256(abi.encodePacked((lender)));   
    isCompoundV3Flag = _lender == ${arr.map((a) => `keccak256(abi.encodePacked((${a})))`).join(" || _lender == ")};
  }`;
};

const isCompoundV2 = (arr: string[]) => {
    return `function  isCompoundV2(string memory lender) internal pure returns(bool isCompoundV2Flag) {
    bytes32 _lender = keccak256(abi.encodePacked((lender)));   
    isCompoundV2Flag = _lender == ${arr.map((a) => `keccak256(abi.encodePacked((${a})))`).join(" || _lender == ")};
  }`;
};

function getChainString(s: any) {
    return CHAIN_INFO[s].enum;
}

function getChainId(s: any) {
    return CHAIN_INFO[s].chainId;
}

function getChainRpc(s: any) {
    return CHAIN_INFO[s].rpc?.filter((rpc) => !rpc.includes("$"))[0] || ""; // filter out the ones with env vars
}

const chainLibHeader = () => `

library Chains {

`;

const tokenLibHeader = () => `

library Tokens {

`;

const lenderLibHeader = () => `

library Lenders {

`;

async function main() {
    await fetchLenderMetaFromDirAndInitialize();

    let chainIdsCovered: any[] = [];
    let lendersCovered: any[] = [];

    let aaves: string[] = [];
    let compoundV3s: string[] = [];
    let compoundV2s: string[] = [];

    // manual overrides for chains
    chainIdsCovered.push("1284"); // Moonbeam
    chainIdsCovered.push("25"); // cronos

    // aave
    Object.entries(aavePools()).forEach(([lender, maps]) => {
        lendersCovered.push(lender);
        aaves.push(lender);
        Object.entries(maps).forEach(([chains, _]) => {
            chainIdsCovered.push(chains);
        });
    });

    Object.keys(morphoPools().MORPHO_BLUE).forEach((chainId) => chainIdsCovered.push(chainId));

    // compound V3
    Object.entries(compoundV3Pools()).forEach(([chain, maps]) => {
        chainIdsCovered.push(chain);
        Object.entries(maps).forEach(([lender, _]) => {
            compoundV3s.push(lender);
            lendersCovered.push(lender);
        });
    });

    // compound V2
    Object.entries(compoundV2Pools()).forEach(([lender, maps]) => {
        lendersCovered.push(lender);
        compoundV2s.push(lender);
        Object.entries(maps).forEach(([chains, _]) => {
            chainIdsCovered.push(chains);
        });
    });

    ///////////////////////////////////////////////////////////////
    // Create libraries first to reference them in the constructor
    ///////////////////////////////////////////////////////////////
    // 1. Chain library
    let chainLib = chainLibHeader();
    const uniqueChains = uniq(chainIdsCovered).map((c) => getChainString(c));
    uniqueChains.forEach((chain) => {
        chainLib += `    string internal constant ${chain} = "${chain}";\n`;
    });
    chainLib += `}\n`;
    ///////////////////////////////////////////////////////////////
    // 2. Token collection and library creation
    ///////////////////////////////////////////////////////////////
    let chainToToken: {[a: string]: string[]} = {};
    // Collect all tokens
    // AAVE tokens
    Object.entries(aaveTokens()).forEach(([lender, chainTokens]) => {
        Object.entries(chainTokens).forEach(([chainId, _]) => {
            if (!chainToToken[chainId]) chainToToken[chainId] = [];
            chainToToken[chainId] = [...chainToToken[chainId], ...aaveReserves()[lender][chainId]];
        });
    });
    // COMPOUND V3 tokens
    Object.entries(compoundV3Pools()).forEach(([chain, lenderToComet]) => {
        Object.entries(lenderToComet).forEach(([lender, _]) => {
            if (!chainToToken[chain]) chainToToken[chain] = [];
            chainToToken[chain] = [...chainToToken[chain], ...compoundV3Reserves()[lender][chain]];
        });
    });
    // COMPOUND V2 tokens
    Object.entries(compoundV2Tokens()).forEach(([lender, chainTokens]) => {
        Object.entries(chainTokens).forEach(([chainId, _]) => {
            if (!chainToToken[chainId]) chainToToken[chainId] = [];
            chainToToken[chainId] = [...chainToToken[chainId], ...compoundV2Reserves()[lender][chainId]];
        });
    });

    ///////////////////////////////////////////////////////////////
    // 3. Create token symbols library
    ///////////////////////////////////////////////////////////////
    let tokenSymbols: string[] = [];
    Object.entries(chainToToken).forEach(([chain, tokenList]) => {
        const _tokenListClean = uniq(tokenList);
        _tokenListClean.forEach((token) => {
            const meta = ASSET_META[chain]?.[token];
            if (meta && !meta.assetGroup?.endsWith(")")) {
                const key = symbolToKey(meta.symbol) ?? meta.symbol;
                tokenSymbols.push(key);
            }
        });
    });

    let tokenLib = tokenLibHeader();
    uniq(tokenSymbols).forEach((symbol) => {
        tokenLib += `    string internal constant ${symbol} = "${symbol}";\n`;
    });
    tokenLib += `}\n`;

    ///////////////////////////////////////////////////////////////
    // 4. Lender library
    ///////////////////////////////////////////////////////////////
    let lenderLib = lenderLibHeader();
    const uniqueLenders = uniq(lendersCovered);
    uniqueLenders.forEach((lender) => {
        lenderLib += `    string internal constant ${lender} = "${lender}";\n`;
    });

    lenderLib += isAave(uniq(aaves));
    lenderLib += isCompoundV3(uniq(compoundV3s));
    lenderLib += isCompoundV2(uniq(compoundV2s));
    lenderLib += `}\n`;

    ///////////////////////////////////////////////////////////////
    // Generate main contract
    ///////////////////////////////////////////////////////////////
    let data = contractHeader();

    // Begin constructor
    data += `constructor() {\n`;

    // Add Chain Info
    const uniqueChainIds = uniq(chainIdsCovered);
    uniqueChainIds.forEach((chain) => {
        const chainConstant = `Chains.${getChainString(chain)}`;
        const rpcUrl = getChainRpc(chain);
        const chainId = getChainId(chain);

        data += `    chainInfo[${chainConstant}] = ChainInfo("${rpcUrl}", ${chainId});\n`;
    });
    data += `\n`;

    // AAVE DATA
    data += `    // Initialize AAVE protocol data\n`;
    Object.entries(aavePools()).forEach(([lender, maps]) => {
        const tokens = aaveTokens()[lender];

        // add aave tokens
        Object.entries(tokens).forEach(([chainId, tokens]) => {
            const chainConstant = `Chains.${getChainString(chainId)}`;
            const lenderConstant = `Lenders.${lender}`;

            Object.entries(tokens).forEach(([reserve, lenderTokens]) => {
                const meta = ASSET_META[chainId]?.[reserve];
                if (meta && !meta.assetGroup?.endsWith(")")) {
                    data += `    lendingTokens[${chainConstant}][${lenderConstant}][${getAddress(reserve)}] = LenderTokens(${getAddress(
                        lenderTokens.aToken
                    )},${getAddress(lenderTokens.vToken)},${getAddress(lenderTokens.sToken)});\n`;
                }
            });
        });

        // add pools
        Object.entries(maps).forEach(([chain, aaveInfoData]) => {
            const chainConstant = `Chains.${getChainString(chain)}`;
            const lenderConstant = `Lenders.${lender}`;
            data += `    lendingControllers[${chainConstant}][${lenderConstant}] = ${getAddress(aaveInfoData.pool)};\n`;
        });
    });
    data += `\n`;

    // COMPOUND V3 DATA
    data += `    // Initialize Compound V3 protocol data\n`;
    Object.entries(compoundV3Pools()).forEach(([chain, lenderToComet]) => {
        const chainConstant = `Chains.${getChainString(chain)}`;

        // add comets and controllers
        Object.entries(lenderToComet).forEach(([lender, comet]) => {
            const lenderConstant = `Lenders.${lender}`;
            data += `    lendingControllers[${chainConstant}][${lenderConstant}] = ${getAddress(comet as any)};\n`;
        });
    });

    // map comets to base
    Object.entries(compoundV3BaseData()).forEach(([lender, chainIdToBase]) => {
        const lenderConstant = `Lenders.${lender}`;

        Object.entries(chainIdToBase).forEach(([chainId, baseData]) => {
            const chainConstant = `Chains.${getChainString(chainId)}`;
            data += `    cometToBase[${chainConstant}][${lenderConstant}] = ${getAddress(baseData.baseAsset)};\n`;
        });
    });
    data += `\n`;

    // COMPOUND V2 DATA
    data += `    // Initialize Compound V2 protocol data\n`;
    Object.entries(compoundV2Pools()).forEach(([lender, maps]) => {
        const lenderConstant = `Lenders.${lender}`;
        const tokens = compoundV2Tokens()[lender];

        // add compound v2 tokens
        Object.entries(tokens).forEach(([chainId, tokens]) => {
            const chainConstant = `Chains.${getChainString(chainId)}`;

            Object.entries(tokens).forEach(([reserve, lenderTokens]) => {
                const meta = ASSET_META[chainId]?.[reserve];
                if ((meta && !meta.assetGroup?.endsWith(")")) || reserve === "0x0000000000000000000000000000000000000000") {
                    data += `    lendingTokens[${chainConstant}][${lenderConstant}][${getAddress(reserve)}] = LenderTokens(${getAddress(
                        lenderTokens
                    )}, address(0), address(0));\n`;
                }
            });
        });

        // add pools
        Object.entries(maps).forEach(([chain, comptroller]) => {
            const chainConstant = `Chains.${getChainString(chain)}`;
            data += `    lendingControllers[${chainConstant}][${lenderConstant}] = ${getAddress(comptroller)};\n`;
        });
    });
    data += `\n`;

    // add token addresses
    data += `    // Initialize token addresses\n`;
    Object.entries(chainToToken).forEach(([chain, tokenList]) => {
        const chainConstant = `Chains.${getChainString(chain)}`;
        const _tokenListClean = uniq(tokenList);

        _tokenListClean.forEach((token) => {
            const meta = ASSET_META[chain]?.[token];
            // skip non-mapped for now
            if (meta && !meta.assetGroup?.endsWith(")")) {
                const key = symbolToKey(meta.symbol) ?? meta.symbol;
                const tokenConstant = `Tokens.${key}`;
                data += `    tokens[${chainConstant}][${tokenConstant}] = ${getAddress(token)};\n`;
            }
        });
    });

    // close constructor
    data += `}\n\n`;

    // Add getter functions for chain information
    data += `    function _getChainRpc(string memory chainName) internal view returns (string memory) {\n`;
    data += `        return chainInfo[chainName].rpcUrl;\n`;
    data += `    }\n\n`;

    data += `    function _getChainId(string memory chainName) internal view returns (uint256) {\n`;
    data += `        return chainInfo[chainName].chainId;\n`;
    data += `    }\n\n`;

    // close contract part
    data += `}\n`;

    // Append the libraries
    data += chainLib;
    data += tokenLib;
    data += lenderLib;

    const filePath = `./test/data/LenderRegistry.sol`;
    fs.writeFileSync(filePath, data);
    console.log(`Generated LenderRegistry.sol with library constants`);
}

/** Copy-pasted from the registry to create valid enum names for assets */

/** Generate a valid enum key for an asset */
function symbolToKey(s: string) {
    let adjusted = s;
    if (!isNaN(Number(adjusted[0]))) {
        const fl = adjusted[0];
        const word = numberToWords(Number(fl)).replaceAll(" ", "_").toUpperCase();
        adjusted = word + "_" + adjusted.slice(1);
    }
    let symb = replacePlusSymbol(adjusted.replaceAll(" ", "_").replaceAll("-", "_").replaceAll(".", "_").replaceAll("/", "").toUpperCase());
    symb = mapSpecialSymbols(symb);

    if (isAlphaNumericOrDollar(symb)) return symb;
    return undefined;
}

// convert number to a word
function numberToWords(num: number) {
    if (num === 0) return "zero";
    const ones = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"];
    return ones[num];
}

function replacePlusSymbol(str: string) {
    // @ts-ignore
    return str
        .replace(/\++/, (match, offset, input) => {
            // Check if the match is at the end of the string
            if (offset === input.length - 1) {
                return "_PLUS_PLUS";
            }
            return "_PLUS_PLUS_";
            // @ts-ignore
        })
        .replace(/\+/, (match, offset, input) => {
            // Check if the match is at the end of the string
            if (offset === input.length - 1) {
                return "_PLUS";
            }
            return "_PLUS_";
        });
}
function isAlphaNumericOrDollar(str: string) {
    // Test the string with a regular expression that includes the "$" symbol
    return /^[a-zA-Z0-9$_]*$/.test(str);
}
function mapSpecialSymbols(s: string) {
    return s.replaceAll("!", "E").replaceAll("?", "Q");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
