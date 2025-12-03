import {AAVE_V2_LENDERS, AAVE_V3_LENDERS} from "@1delta/lender-registry";
import {BALANCER_V2_FORKS, FLASH_LOAN_IDS} from "@1delta/dex-registry";
import * as fs from "fs";
import {CREATE_CHAIN_IDS, getChainEnum} from "../config";
import path from "path";
import {templateAaveV3Test} from "../templates/test/templates/aaveV3CallbackTest";
import {templateAaveV2Test} from "../templates/test/templates/aaveV2CallbackTest";
import {templateBalancerV2Test} from "../templates/test/templates/balancerV2CallbackTest";
import {CANCUN_OR_HIGHER} from "../chain/evmVersion";
import {fetchLenderMetaFromDirAndInitialize} from "../utils";
import {aavePools} from "@1delta/data-sdk";
import {Chain} from "@1delta/chain-registry";
import {Lender} from "@1delta/asset-registry";

interface LenderData {
    entityName: string;
    entityId: string;
    pool: string;
    assetType: string;
}

async function main() {
    await fetchLenderMetaFromDirAndInitialize();
    const chains = CREATE_CHAIN_IDS;

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i];
        const isCancun = CANCUN_OR_HIGHER.includes(chain);
        console.log(`Generating test files for chain: ${chain}`);
        const key = getChainEnum(chain);

        let lendersAaveV3: LenderData[] = [];
        let lendersAaveV2: LenderData[] = [];
        let poolsBalancerV2: LenderData[] = [];

        // Collect AaveV2 and AaveV3 lenders
        Object.entries(aavePools()).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chainId, e]) => {
                if (chainId === chain) {
                    // Determine default asset type for this lender
                    const assetType = determineDefaultAssetType(lender, chainId);

                    if (AAVE_V2_LENDERS.includes(lender as any)) {
                        if (FLASH_LOAN_IDS[lender] !== undefined)
                            lendersAaveV2.push({
                                entityName: lender,
                                entityId: FLASH_LOAN_IDS[lender].toString(),
                                pool: e.pool,
                                assetType,
                            });
                    }

                    if (AAVE_V3_LENDERS.includes(lender as any)) {
                        if (FLASH_LOAN_IDS[lender] !== undefined)
                            lendersAaveV3.push({
                                entityName: lender,
                                entityId: FLASH_LOAN_IDS[lender].toString(),
                                pool: e.pool,
                                assetType,
                            });
                    }
                }
            });
        });

        // Collect Balancer V2 pools
        Object.entries(BALANCER_V2_FORKS).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chainId, e]) => {
                if (chainId === chain) {
                    const assetType = determineDefaultAssetType(lender, chainId);
                    poolsBalancerV2.push({
                        entityName: lender,
                        entityId: FLASH_LOAN_IDS[lender].toString(),
                        pool: e,
                        assetType,
                    });
                }
            });
        });

        // Sort by entity ID
        lendersAaveV2 = lendersAaveV2.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        lendersAaveV3 = lendersAaveV3.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));
        poolsBalancerV2 = poolsBalancerV2.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));

        // Create the test files directory
        const testDir = `./test/composer/lending/callbacks/`;
        fs.mkdirSync(testDir, {recursive: true});

        if (lendersAaveV3.length > 0) {
            const chainKeyForFile = key.toLowerCase();
            const filePath = path.join(testDir, "aaveV3", `AaveV3Callback.${chainKeyForFile}.mock.sol`);
            fs.mkdirSync(path.join(testDir, "aaveV3"), {recursive: true});
            console.log(`Generating AaveV3 test file: ${filePath}`);
            fs.writeFileSync(filePath, templateAaveV3Test(key, lendersAaveV3));
        }

        if (lendersAaveV2.length > 0) {
            const chainKeyForFile = key.toLowerCase();
            const filePath = path.join(testDir, "aaveV2", `AaveV2Callback.${chainKeyForFile}.mock.sol`);
            fs.mkdirSync(path.join(testDir, "aaveV2"), {recursive: true});
            console.log(`Generating AaveV2 test file: ${filePath}`);
            fs.writeFileSync(filePath, templateAaveV2Test(key, lendersAaveV2));
        }

        if (poolsBalancerV2.length > 0) {
            const chainKeyForFile = key.toLowerCase();
            const filePath = path.join(testDir, "balancerV2", `BalancerV2Callback.${chainKeyForFile}.mock.sol`);
            fs.mkdirSync(path.join(testDir, "balancerV2"), {recursive: true});
            console.log(`Generating BalancerV2 test file: ${filePath}`);
            fs.writeFileSync(filePath, templateBalancerV2Test(key, poolsBalancerV2, isCancun));
        }

        console.log(`Generated test files for chain ${chain}`);
    }
}

// Helper function to determine a default asset type based on the lender name
function determineDefaultAssetType(lenderName: string, chainId: string): string {
    // Default to USDC
    let defaultAsset = "USDC";

    // Check for BTC in the name
    if (lenderName.includes("WBTC")) {
        defaultAsset = "WBTC";
    } else if (lenderName.includes("STBTC")) {
        defaultAsset = "STBTC";
    } else if (lenderName.includes("LBTC")) {
        defaultAsset = "LBTC";
    } else if (lenderName.includes("XAUM")) {
        defaultAsset = "XAUM";
    } else if (lenderName.includes("LISTA")) {
        defaultAsset = "LISTA";
    } else if (lenderName.includes("USDX")) {
        defaultAsset = "USDX";
    } else if (lenderName === Lender.SEISMIC) {
        defaultAsset = "WETH";
    }

    if (chainId === Chain.METIS_ANDROMEDA_MAINNET) {
        defaultAsset = "WETH";
    } else if (chainId === Chain.HEMI_NETWORK) {
        defaultAsset = "WBTC";
    } else if (chainId === Chain.SONIC_MAINNET) {
        defaultAsset = "WETH";
    }

    if (chainId === Chain.XDC_NETWORK && lenderName === Lender.FATHOM) {
        defaultAsset = "WXDC";
    } else if (chainId === Chain.PLASMA_MAINNET && lenderName === Lender.AAVE_V3) {
        defaultAsset = "WETH";
    } else if (chainId === Chain.CORE_BLOCKCHAIN_MAINNET && lenderName === Lender.AVALON) {
        defaultAsset = "SOLVBTC_B";
    } else if (chainId === Chain.FANTOM_OPERA && lenderName === Lender.GRANARY) {
        defaultAsset = "WFTM";
    } else if (chainId === Chain.BERACHAIN && lenderName === Lender.ZEROLEND) {
        defaultAsset = "WETH";
    } else if (chainId === Chain.BLAST) {
        defaultAsset = "WETH";
    }

    return defaultAsset;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
