import axios from "axios";
import {CREATE_CHAIN_IDS} from "./_create/config";
import {CHAIN_INFO} from "@1delta/asset-registry";
import * as fs from "fs";
import * as path from "path";
import crypto from "crypto";

interface ChainConfig {
    name: string;
    chainId: number;
    rpcUrls: string[];
}

interface BytecodeResult {
    chain: string;
    chainId: number;
    rpcUrl: string;
    bytecode: string;
    bytecodeHash: string;
    error?: string;
    deployed: boolean;
    retries?: number;
}

interface ReportData {
    contractAddress: string;
    timestamp: string;
    totalChains: number;
    chainsWithContract: number;
    chainsWithoutContract: number;
    matchingGroups: string[][];
    results: BytecodeResult[];
}

function getChainIdFromChainEnum(chainEnum: string): number | null {
    const chainInfo = CHAIN_INFO[chainEnum];
    if (!chainInfo || !chainInfo.chainId) {
        return null;
    }
    return parseInt(chainInfo.chainId.toString(), 10);
}

function extractChainConfigs(): ChainConfig[] {
    const chainConfigs: ChainConfig[] = [];

    for (const chainEnum of CREATE_CHAIN_IDS) {
        const chainId = getChainIdFromChainEnum(chainEnum);
        if (!chainId) {
            console.warn(`Warning: Could not find chainId for ${chainEnum}`);
            continue;
        }

        const chainInfo = CHAIN_INFO[chainEnum];
        if (!chainInfo) {
            console.warn(`Warning: Could not find chain info for ${chainEnum}`);
            continue;
        }

        const chainName = chainInfo.name || chainEnum;
        const rpcUrls = (chainInfo.rpc || []).filter((rpc: string) => !rpc.includes("$"));

        if (rpcUrls.length === 0) {
            console.warn(`Warning: Could not find RPC URL for ${chainEnum}`);
            continue;
        }

        chainConfigs.push({
            name: chainName,
            chainId,
            rpcUrls,
        });
    }

    return chainConfigs;
}

async function getCode(rpcUrl: string, contractAddress: string, requestId: number): Promise<string> {
    const response = await axios.post(
        rpcUrl,
        {
            jsonrpc: "2.0",
            id: requestId,
            method: "eth_getCode",
            params: [contractAddress, "latest"],
        },
        {
            timeout: 30000,
            headers: {
                "Content-Type": "application/json",
            },
        }
    );

    if (response.data.error) {
        throw new Error(response.data.error.message || "RPC error");
    }

    return response.data.result || "0x";
}

async function getCodeWithRetry(
    rpcUrls: string[],
    contractAddress: string,
    requestId: number,
    chainName: string
): Promise<{bytecode: string; rpcUrl: string; retries: number}> {
    let lastError: Error | null = null;
    let retries = 0;

    for (let i = 0; i < rpcUrls.length; i++) {
        const rpcUrl = rpcUrls[i];
        try {
            const bytecode = await getCode(rpcUrl, contractAddress, requestId);
            return {bytecode, rpcUrl, retries: i};
        } catch (error: any) {
            lastError = error;
            retries = i + 1;
        }
    }

    if (lastError) {
        throw lastError;
    }
    throw new Error("No RPC URLs available");
}

function hashBytecode(bytecode: string): string {
    const normalized = bytecode.toLowerCase().startsWith("0x") ? bytecode.slice(2) : bytecode;
    return crypto.createHash("sha256").update(normalized, "hex").digest("hex");
}

async function fetchBytecodes(contractAddress: string, chainConfigs: ChainConfig[]): Promise<BytecodeResult[]> {
    const results: BytecodeResult[] = [];

    console.log(`\nFetching bytecode from ${chainConfigs.length} chains...\n`);

    const promises = chainConfigs.map(async (chainConfig, index) => {
        try {
            const {bytecode, rpcUrl, retries} = await getCodeWithRetry(chainConfig.rpcUrls, contractAddress, index + 1, chainConfig.name);
            const normalizedBytecode = bytecode === "0x" || bytecode === "" ? "" : bytecode;
            const deployed = normalizedBytecode !== "";
            const bytecodeHash = deployed ? hashBytecode(normalizedBytecode) : "";

            return {
                chain: chainConfig.name,
                chainId: chainConfig.chainId,
                rpcUrl,
                bytecode: normalizedBytecode,
                bytecodeHash,
                deployed,
                retries: retries > 0 ? retries : undefined,
            };
        } catch (error: any) {
            return {
                chain: chainConfig.name,
                chainId: chainConfig.chainId,
                rpcUrl: chainConfig.rpcUrls[0] || "N/A",
                bytecode: "",
                bytecodeHash: "",
                error: error.message || "Unknown error",
                deployed: false,
                retries: chainConfig.rpcUrls.length,
            };
        }
    });

    const fetchedResults = await Promise.all(promises);
    results.push(...fetchedResults);

    return results;
}

function compareBytecodes(results: BytecodeResult[]): string[][] {
    const bytecodeGroups: Map<string, string[]> = new Map();

    for (const result of results) {
        if (!result.deployed || result.error) {
            continue;
        }

        const hash = result.bytecodeHash;
        if (!bytecodeGroups.has(hash)) {
            bytecodeGroups.set(hash, []);
        }
        bytecodeGroups.get(hash)!.push(result.chain);
    }

    return Array.from(bytecodeGroups.values());
}

function generateMarkdownReport(reportData: ReportData): string {
    const {contractAddress, timestamp, totalChains, chainsWithContract, chainsWithoutContract, matchingGroups, results} = reportData;

    let markdown = `# Bytecode Verification Report\n\n`;
    markdown += `**Contract Address:** \`${contractAddress}\`\n\n`;
    markdown += `**Generated:** ${timestamp}\n\n`;
    markdown += `---\n\n`;

    markdown += `## Summary\n\n`;
    markdown += `- **Total Chains Checked:** ${totalChains}\n`;
    markdown += `- **Chains With Contract:** ${chainsWithContract}\n`;
    markdown += `- **Chains Without Contract:** ${chainsWithoutContract}\n`;
    markdown += `- **Unique Bytecode Groups:** ${matchingGroups.length}\n\n`;

    if (matchingGroups.length > 0) {
        markdown += `## Bytecode Groups\n\n`;
        matchingGroups.forEach((group, index) => {
            markdown += `### Group ${index + 1} (${group.length} chain${group.length > 1 ? "s" : ""})\n\n`;
            markdown += `Chains with matching bytecode:\n`;
            group.forEach((chain) => {
                markdown += `- ${chain}\n`;
            });
            markdown += `\n`;
        });
    }

    markdown += `## Detailed Results\n\n`;
    markdown += `| Chain | Chain ID | Deployed | Bytecode Hash | Retries | Status |\n`;
    markdown += `|-------|----------|----------|---------------|---------|--------|\n`;

    results.forEach((result) => {
        const status = result.error ? `❌ Error: ${result.error}` : result.deployed ? "✅ Deployed" : "❌ Not Deployed";
        const hashDisplay = result.bytecodeHash ? `${result.bytecodeHash.substring(0, 16)}...` : "N/A";
        const retriesDisplay = result.retries !== undefined ? result.retries : "-";
        markdown += `| ${result.chain} | ${result.chainId} | ${result.deployed ? "Yes" : "No"} | ${hashDisplay} | ${retriesDisplay} | ${status} |\n`;
    });

    markdown += `\n---\n\n`;
    markdown += `## RPC Endpoints\n\n`;
    markdown += `| Chain | RPC URL |\n`;
    markdown += `|-------|----------|\n`;

    results.forEach((result) => {
        markdown += `| ${result.chain} | \`${result.rpcUrl}\` |\n`;
    });

    return markdown;
}

function printConsoleSummary(reportData: ReportData): void {
    const {contractAddress, totalChains, chainsWithContract, chainsWithoutContract, matchingGroups, results} = reportData;

    console.log("\n" + "=".repeat(60));
    console.log("BYTECODE VERIFICATION SUMMARY");
    console.log("=".repeat(60));
    console.log(`Contract Address: ${contractAddress}`);
    console.log(`Total Chains Checked: ${totalChains}`);
    console.log(`Chains With Contract: ${chainsWithContract}`);
    console.log(`Chains Without Contract: ${chainsWithoutContract}`);
    console.log(`Unique Bytecode Groups: ${matchingGroups.length}`);
    console.log("=".repeat(60));

    if (matchingGroups.length > 0) {
        console.log("\nBytecode Groups:");
        matchingGroups.forEach((group, index) => {
            console.log(`\nGroup ${index + 1} (${group.length} chain${group.length > 1 ? "s" : ""}):`);
            group.forEach((chain) => console.log(`  - ${chain}`));
        });
    }

    const errorChains = results.filter((r) => r.error);
    if (errorChains.length > 0) {
        console.log("\nChains with errors:");
        errorChains.forEach((result) => {
            const retryInfo = result.retries ? ` (tried ${result.retries} RPC${result.retries > 1 ? "s" : ""})` : "";
            console.log(`  - ${result.chain}: ${result.error}${retryInfo}`);
        });
    }

    const retriedChains = results.filter((r) => r.retries && r.retries > 0 && !r.error);
    if (retriedChains.length > 0) {
        console.log("\nChains that required retries (but succeeded):");
        retriedChains.forEach((result) => {
            console.log(`  - ${result.chain}: succeeded after ${result.retries} attempt${result.retries! > 1 ? "s" : ""}`);
        });
    }

    const notDeployedChains = results.filter((r) => !r.deployed && !r.error);
    if (notDeployedChains.length > 0) {
        console.log("\nChains where contract is not deployed:");
        notDeployedChains.forEach((result) => {
            console.log(`  - ${result.chain} (Chain ID: ${result.chainId})`);
        });
    }

    console.log("\n" + "=".repeat(60));
}

async function main() {
    const contractAddress = process.argv[2];

    if (!contractAddress) {
        console.error("Error: Contract address is required");
        console.error("Usage: tsx scripts/verify-bytecode.ts <contract_address>");
        process.exit(1);
    }

    if (!contractAddress.match(/^0x[a-fA-F0-9]{40}$/)) {
        console.error("Error: Invalid contract address format");
        process.exit(1);
    }

    console.log("Extracting chain configurations...");
    const chainConfigs = extractChainConfigs();

    if (chainConfigs.length === 0) {
        console.error("Error: No valid chain configurations found");
        process.exit(1);
    }

    console.log(`Found ${chainConfigs.length} chains to check`);

    const results = await fetchBytecodes(contractAddress, chainConfigs);

    const chainsWithContract = results.filter((r) => r.deployed && !r.error).length;
    const chainsWithoutContract = results.filter((r) => !r.deployed && !r.error).length;
    const matchingGroups = compareBytecodes(results);

    const reportData: ReportData = {
        contractAddress,
        timestamp: new Date().toISOString(),
        totalChains: chainConfigs.length,
        chainsWithContract,
        chainsWithoutContract,
        matchingGroups,
        results,
    };

    printConsoleSummary(reportData);

    const markdownReport = generateMarkdownReport(reportData);

    const reportsDir = path.join(process.cwd(), "reports");
    if (!fs.existsSync(reportsDir)) {
        fs.mkdirSync(reportsDir, {recursive: true});
    }

    const now = new Date();
    const dateStr = now.toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const fileName = `bytecode-report-${dateStr}.md`;
    const reportPath = path.join(reportsDir, fileName);

    fs.writeFileSync(reportPath, markdownReport, "utf-8");

    console.log(`\nMarkdown report saved to: ${reportPath}`);
}

main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
