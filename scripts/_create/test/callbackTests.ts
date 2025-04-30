import {AAVE_FORK_POOL_DATA, AAVE_V3_LENDERS, Chain} from "@1delta/asset-registry";
import {FLASH_LOAN_IDS} from "@1delta/dex-registry";
import * as fs from "fs";
import {CREATE_CHAIN_IDS, getChainEnum} from "../config";
import {templateAaveV3Test} from "../templates/flashLoan/aaveV3CallbackTest";

interface LenderData {
    entityName: string;
    entityId: string;
    pool: string;
    assetType: string;
}

async function main() {
    const chains = CREATE_CHAIN_IDS;

    for (let i = 0; i < chains.length; i++) {
        const chain = chains[i];
        console.log(`Generating test files for chain: ${chain}`);
        const key = getChainEnum(chain);

        let lendersAaveV3: LenderData[] = [];

        // Collect AaveV3 lenders
        Object.entries(AAVE_FORK_POOL_DATA).forEach(([lender, maps]) => {
            Object.entries(maps).forEach(([chainId, e]) => {
                if (chainId === chain) {
                    // Determine default asset type for this lender
                    const assetType = determineDefaultAssetType(lender, chainId);

                    if (AAVE_V3_LENDERS.includes(lender as any)) {
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

        // Sort by entity ID
        lendersAaveV3 = lendersAaveV3.sort((a, b) => (Number(a.entityId) < Number(b.entityId) ? -1 : 1));

        // Create the test files directory
        const testDir = `./test/composer/lending/callbacks/`;
        fs.mkdirSync(testDir, {recursive: true});

        if (lendersAaveV3.length > 0) {
            const chainKeyForFile = key.toLowerCase();
            const filePath = `${testDir}AaveV3Callback.${chainKeyForFile}.mock.sol`;
            console.log(`Generating AaveV3 test file: ${filePath}`);
            fs.writeFileSync(filePath, templateAaveV3Test(key, lendersAaveV3));
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
    }

    if (chainId === Chain.METIS_ANDROMEDA_MAINNET) {
        defaultAsset = "WETH";
    } else if (chainId === Chain.HEMI_NETWORK) {
        defaultAsset = "WBTC";
    } else if (chainId === Chain.SONIC_MAINNET) {
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
