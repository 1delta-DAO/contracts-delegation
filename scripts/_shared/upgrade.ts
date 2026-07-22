import { artifacts, ethers } from "hardhat";
import { ProxyAdmin__factory } from "../../types";
import { COMPOSER_LOGICS, COMPOSER_PROXIES, PROXY_ADMINS } from "./addresses";
import { getChainKey, toCamelCaseWithFirstUpper } from "../_create/config";
import { fetchLenderMetaFromDirAndInitialize } from "../_create/utils";

/**
 * Universal gen2 deployer / upgrader.
 *
 * Before pointing a proxy at a new logic (which, for the immutable release, is a decision that is
 * frozen forever once the ProxyAdmin owner is renounced), this verifies the on-chain logic bytecode
 * against the locally-compiled composer artifact, then reads the ERC-1967 implementation slot back
 * after the upgrade to prove it landed. Nothing is upgraded if verification fails.
 *
 * Set VERIFY_ONLY=1 to run the pre-flight checks without sending the upgrade tx.
 */

// keccak256("eip1967.proxy.implementation") - 1
const ERC1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
// keccak256("eip1967.proxy.admin") - 1
const ERC1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function readAddressSlot(proxy: string, slot: string): Promise<string> {
    const raw = await ethers.provider.getStorageAt(proxy, slot);
    return ethers.utils.getAddress("0x" + raw.slice(-40));
}

/**
 * Strip the trailing Solidity CBOR metadata (…a264…<len>) so we can compare the *executable*
 * portion independently of build-environment-dependent metadata (source paths, ipfs hash).
 * The last 2 bytes of runtime bytecode are the big-endian metadata length (excluding those 2 bytes).
 */
function stripMetadata(hexIn: string): string {
    const h = (hexIn.startsWith("0x") ? hexIn.slice(2) : hexIn).toLowerCase();
    if (h.length < 4) return h;
    const metaLen = parseInt(h.slice(-4), 16);
    const cutChars = (metaLen + 2) * 2;
    if (metaLen > 0 && cutChars < h.length) return h.slice(0, h.length - cutChars);
    return h;
}

function normalize(hexIn: string): string {
    return (hexIn.startsWith("0x") ? hexIn.slice(2) : hexIn).toLowerCase();
}

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    // ── resolve the three addresses for this chain (fail fast instead of upgrading `undefined`) ──
    // The addresses.ts maps are keyed by Chain enum values, which are chain-id strings.
    const cid = String(chainId);
    const proxyAdminAddr = (PROXY_ADMINS as Record<string, string>)[cid];
    const proxyAddr = (COMPOSER_PROXIES as Record<string, string>)[cid];
    const logicAddr = (COMPOSER_LOGICS as Record<string, string>)[cid];
    if (!proxyAdminAddr) throw new Error(`No PROXY_ADMINS entry for chain ${chainId}`);
    if (!proxyAddr) throw new Error(`No COMPOSER_PROXIES entry for chain ${chainId}`);
    if (!logicAddr) throw new Error(`No COMPOSER_LOGICS entry for chain ${chainId}`);
    console.log("ProxyAdmin:", proxyAdminAddr);
    console.log("Proxy:     ", proxyAddr);
    console.log("New logic: ", logicAddr);

    // ── verify the new logic bytecode against the locally-compiled composer artifact ──
    await fetchLenderMetaFromDirAndInitialize();
    const key = getChainKey(cid);
    const contractName = `OneDeltaComposer${toCamelCaseWithFirstUpper(key)}`;
    console.log("Verifying logic bytecode against artifact", contractName);

    const artifact = await artifacts.readArtifact(contractName);
    const expected = normalize(artifact.deployedBytecode);
    if (!expected || expected === "0x" || expected.length === 0) {
        throw new Error(`Artifact ${contractName} has empty deployedBytecode — did you run 'hardhat compile'?`);
    }

    const onchain = normalize(await ethers.provider.getCode(logicAddr));
    if (!onchain || onchain.length === 0) {
        // A >24,576-byte contract (EIP-170) silently fails to deploy → empty code. Never upgrade to it.
        throw new Error(`No bytecode at logic ${logicAddr} on chain ${chainId} — not deployed (or EIP-170 deploy failure).`);
    }

    if (onchain === expected) {
        console.log("✅ bytecode exact match (incl. metadata)");
    } else if (stripMetadata(onchain) === stripMetadata(expected)) {
        // Executable code is identical; only the appended metadata (build path / ipfs hash) differs.
        // Behaviourally the audited logic — allowed, but surfaced loudly for the frozen release.
        console.warn("⚠️  executable bytecode matches, but metadata differs (benign build-env difference).");
        console.warn("    on-chain len:", onchain.length / 2, "bytes; artifact len:", expected.length / 2, "bytes");
    } else {
        throw new Error(
            `❌ bytecode MISMATCH at logic ${logicAddr}: on-chain code does not match artifact ${contractName}. ` +
            `Refusing to upgrade the proxy to an unverified logic.`
        );
    }

    // EIP-170 runtime-limit sanity (the deployed logic already passed it, but log it for the record)
    console.log("logic runtime size:", onchain.length / 2, "bytes (EIP-170 limit 24576)");

    // ── admin pre-check: the proxy's ERC-1967 admin MUST be our ProxyAdmin. Otherwise a Transparent
    //    proxy delegates upgradeToAndCall to the implementation and the "upgrade" silently no-ops. ──
    const proxyAdminOnchain = await readAddressSlot(proxyAddr, ERC1967_ADMIN_SLOT);
    console.log("Proxy admin (on-chain):", proxyAdminOnchain);
    if (proxyAdminOnchain.toLowerCase() !== proxyAdminAddr.toLowerCase()) {
        throw new Error(`Proxy ${proxyAddr} admin is ${proxyAdminOnchain}, not the expected ProxyAdmin ${proxyAdminAddr} — upgrade would silently no-op.`);
    }

    // ── ownership pre-check: don't send a tx that is guaranteed to revert ──
    const proxyAdmin = ProxyAdmin__factory.connect(proxyAdminAddr, operator);
    const owner = await proxyAdmin.owner();
    console.log("ProxyAdmin owner:", owner);
    if (owner.toLowerCase() !== operator.address.toLowerCase()) {
        throw new Error(`Operator ${operator.address} is not the ProxyAdmin owner (${owner}) — cannot upgrade.`);
    }

    // ── idempotency: if the proxy already points at the target logic, don't send a redundant
    //    upgrade tx (makes the multi-chain sweep safe to re-run after a crash). ──
    const currentImpl = await readAddressSlot(proxyAddr, ERC1967_IMPL_SLOT);
    console.log("current impl:", currentImpl);
    if (currentImpl.toLowerCase() === logicAddr.toLowerCase()) {
        console.log("✅ proxy already at target logic — nothing to upgrade.");
        return;
    }

    if (process.env.VERIFY_ONLY) {
        console.log("VERIFY_ONLY set — pre-flight checks passed, skipping upgrade.");
        return;
    }

    // ── upgrade ──
    const gl = await proxyAdmin.estimateGas.upgradeAndCall(proxyAddr, logicAddr, "0x");
    const tx = await proxyAdmin.upgradeAndCall(proxyAddr, logicAddr, "0x", { gasLimit: gl });
    console.log("upgrade tx:", tx.hash);
    await tx.wait();

    // ── read the impl slot back and assert the upgrade actually landed ──
    // Load-balanced RPCs can serve the read from a node one block behind right after tx.wait(),
    // returning the stale (pre-upgrade) impl. Poll until it reflects the upgrade before failing.
    let impl = "";
    for (let i = 0; i < 12; i++) {
        impl = await readAddressSlot(proxyAddr, ERC1967_IMPL_SLOT);
        if (impl.toLowerCase() === logicAddr.toLowerCase()) break;
        await sleep(3000); // give the RPC a few seconds to catch up to the receipt's block
    }
    if (impl.toLowerCase() !== logicAddr.toLowerCase()) {
        throw new Error(
            `Post-upgrade impl slot is ${impl}, expected ${logicAddr} after retries. ` +
            `The upgrade tx ${tx.hash} succeeded — this is likely RPC lag; verify on the explorer before re-running.`
        );
    }
    console.log("✅ upgraded — proxy implementation slot now", impl);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
