import {artifacts, ethers} from "hardhat";
import {ProxyAdmin__factory} from "../../types";
import {COMPOSER_LOGICS, COMPOSER_PROXIES, PROXY_ADMINS} from "./addresses";
import {formatEther} from "ethers/lib/utils";
import {getChainKey, toCamelCaseWithFirstUpper} from "../_create/config";
import {fetchLenderMetaFromDirAndInitialize} from "../_create/utils";

/**
 * Soneium "uncensored" upgrade — force the composer upgrade through the L1 OP-Stack portal so the
 * sequencer cannot censor it. Run with --network mainnet (L1 signer); the proxy and all its state
 * live on Soneium (L2), so every verification below runs against the L2 provider.
 *
 * Same checks as scripts/_shared/upgrade.ts, adapted for the cross-chain path:
 *   - proxy admin (L2) IS the expected ProxyAdmin
 *   - the L2 logic bytecode matches the locally-compiled composer artifact (audited build)
 *   - operator is the ProxyAdmin owner (on L2; the EOA is not aliased when it calls the portal)
 *   - idempotent: skips if the L2 proxy already points at the target logic
 *   - the L1 deposit lands on L2 asynchronously, so the post-check POLLS L2 until the impl flips
 *     (it does not throw if L2 is merely slow — a forced deposit can take minutes).
 *
 * Set VERIFY_ONLY=1 to run the L2 pre-flight checks without sending the L1 portal tx.
 */

const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";
const SONEIUM_CHAIN_ID = 1868;
const SONEIUM_RPC = "https://rpc.soneium.org";

// keccak256("eip1967.proxy.implementation") - 1
const ERC1967_IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
// keccak256("eip1967.proxy.admin") - 1
const ERC1967_ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function readAddressSlot(provider: ethers.providers.Provider, proxy: string, slot: string): Promise<string> {
    const raw = await provider.getStorageAt(proxy, slot);
    return ethers.utils.getAddress("0x" + raw.slice(-40));
}

function normalize(hexIn: string): string {
    return (hexIn.startsWith("0x") ? hexIn.slice(2) : hexIn).toLowerCase();
}

/** Strip trailing Solidity CBOR metadata so we compare the executable portion only. */
function stripMetadata(hexIn: string): string {
    const h = normalize(hexIn);
    if (h.length < 4) return h;
    const metaLen = parseInt(h.slice(-4), 16);
    const cutChars = (metaLen + 2) * 2;
    if (metaLen > 0 && cutChars < h.length) return h.slice(0, h.length - cutChars);
    return h;
}

async function main() {
    // L1 signer via hardhat (run with --network mainnet)
    const [_, operator] = await ethers.getSigners();
    const l1Provider = ethers.provider;
    const l2Provider = new ethers.providers.JsonRpcProvider(SONEIUM_RPC);

    const l1ChainId = (await l1Provider.getNetwork()).chainId;
    console.log("L1 sender:  ", operator.address);
    console.log("L1 chain ID:", l1ChainId);
    console.log("L1 balance: ", formatEther(await operator.getBalance()), "ETH");
    if (l1ChainId !== 1) throw new Error(`Expected L1 mainnet (chainId 1) — run with --network mainnet. Connected: ${l1ChainId}`);

    const gasPrice = await l1Provider.getGasPrice();
    console.log("L1 gas price:", gasPrice.toNumber() / 1e9, "gwei");

    const cid = String(SONEIUM_CHAIN_ID);
    const proxyAdmin = (PROXY_ADMINS as Record<string, string>)[cid];
    const composerProxy = (COMPOSER_PROXIES as Record<string, string>)[cid];
    const composerLogic = (COMPOSER_LOGICS as Record<string, string>)[cid];
    if (!proxyAdmin) throw new Error(`No PROXY_ADMINS entry for Soneium (${cid})`);
    if (!composerProxy) throw new Error(`No COMPOSER_PROXIES entry for Soneium (${cid})`);
    if (!composerLogic) throw new Error(`No COMPOSER_LOGICS entry for Soneium (${cid})`);
    console.log("ProxyAdmin:     ", proxyAdmin);
    console.log("Proxy:          ", composerProxy);
    console.log("New logic:      ", composerLogic);

    // ── L2 pre-flight (all state lives on Soneium) ──

    // 1. proxy admin (L2) must be our ProxyAdmin
    const adminOnL2 = await readAddressSlot(l2Provider, composerProxy, ERC1967_ADMIN_SLOT);
    console.log("Proxy admin (L2):", adminOnL2);
    if (adminOnL2.toLowerCase() !== proxyAdmin.toLowerCase()) {
        throw new Error(`Proxy ${composerProxy} admin (L2) is ${adminOnL2}, not the expected ProxyAdmin ${proxyAdmin}.`);
    }

    // 2. operator must be the ProxyAdmin owner on L2 (the portal EOA is NOT aliased)
    const proxyAdminL2 = ProxyAdmin__factory.connect(proxyAdmin, l2Provider);
    const owner = await proxyAdminL2.owner();
    console.log("ProxyAdmin owner (L2):", owner);
    if (owner.toLowerCase() !== operator.address.toLowerCase()) {
        throw new Error(`Operator ${operator.address} is not the ProxyAdmin owner (${owner}) on L2 — the forced upgrade would revert.`);
    }

    // 3. the L2 logic bytecode must match the locally-compiled composer artifact (audited build)
    await fetchLenderMetaFromDirAndInitialize();
    const contractName = `OneDeltaComposer${toCamelCaseWithFirstUpper(getChainKey(cid))}`;
    console.log("Verifying L2 logic bytecode against artifact", contractName);
    const expected = normalize((await artifacts.readArtifact(contractName)).deployedBytecode);
    const onchain = normalize(await l2Provider.getCode(composerLogic));
    if (onchain.length === 0) throw new Error(`No bytecode at logic ${composerLogic} on Soneium — not deployed (or EIP-170 deploy failure).`);
    if (onchain === expected) {
        console.log("✅ L2 bytecode exact match (incl. metadata)");
    } else if (stripMetadata(onchain) === stripMetadata(expected)) {
        console.warn("⚠️  L2 executable bytecode matches, metadata differs (benign build-env difference).");
    } else {
        throw new Error(`❌ L2 logic bytecode does not match artifact ${contractName}. Refusing to force an unverified upgrade.`);
    }

    // 4. idempotency: skip if the L2 proxy already points at the target logic
    const implNow = await readAddressSlot(l2Provider, composerProxy, ERC1967_IMPL_SLOT);
    console.log("current impl (L2):", implNow);
    if (implNow.toLowerCase() === composerLogic.toLowerCase()) {
        console.log("✅ Soneium proxy already at target logic — nothing to upgrade.");
        return;
    }

    if (process.env.VERIFY_ONLY) {
        console.log("VERIFY_ONLY set — L2 pre-flight checks passed, skipping the L1 portal tx.");
        return;
    }

    // ── force the upgrade through the L1 portal ──
    // Encode upgradeAndCall(proxy, logic, "0x")
    const calldata = ProxyAdmin__factory.createInterface().encodeFunctionData("upgradeAndCall", [composerProxy, composerLogic, "0x"]);

    // Estimate L2 gas
    let l2GasLimit: number;
    try {
        const l2Estimate = await l2Provider.estimateGas({
            from: operator.address, // EOA — no alias
            to: proxyAdmin,
            data: calldata,
        });
        l2GasLimit = Math.ceil(l2Estimate.toNumber() * 1.25);
        console.log("L2 gas estimate:", l2Estimate.toString(), "→ using", l2GasLimit);
    } catch (e) {
        console.warn("L2 gas estimation failed, falling back to 500_000:", e);
        l2GasLimit = 500_000;
    }

    const portal = new ethers.Contract(PORTAL, ["function depositTransaction(address,uint256,uint64,bool,bytes) payable"], operator);

    const boostedGasPrice = gasPrice.mul(150).div(100);

    const l1GasEstimate = await portal.estimateGas.depositTransaction(
        proxyAdmin, // to: ProxyAdmin on L2
        0,
        l2GasLimit,
        false, // isCreation: false — calling existing contract
        calldata,
        {value: 0}
    );
    console.log("L1 gas estimate:", l1GasEstimate.toString());
    console.log("Estimated L1 cost:", formatEther(l1GasEstimate.mul(boostedGasPrice)), "ETH");

    console.log("\nSending forced upgradeAndCall via L1 portal...");

    const tx = await portal.depositTransaction(proxyAdmin, 0, l2GasLimit, false, calldata, {gasPrice: boostedGasPrice});

    console.log("L1 tx hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("L1 tx confirmed in block:", receipt.blockNumber);

    // ── async post-check: poll L2 until the impl reflects the upgrade (forced deposits take minutes) ──
    console.log("\nWaiting for the forced deposit to execute on Soneium (this can take a few minutes)...");
    let landed = false;
    for (let i = 0; i < 40; i++) {
        // ~40 × 15s ≈ 10 min
        const impl = await readAddressSlot(l2Provider, composerProxy, ERC1967_IMPL_SLOT);
        if (impl.toLowerCase() === composerLogic.toLowerCase()) {
            landed = true;
            break;
        }
        await sleep(15000);
    }
    if (landed) {
        console.log("✅ upgrade landed on Soneium — proxy implementation slot now", composerLogic);
    } else {
        console.warn(
            `\n⚠️  Not yet reflected on Soneium after ~10 min. The L1 deposit (${tx.hash}) is confirmed; forced ` +
                `inclusion can lag longer. Re-run this script to poll again — it will detect the landed upgrade ` +
                `via the idempotency check and exit cleanly.`
        );
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
