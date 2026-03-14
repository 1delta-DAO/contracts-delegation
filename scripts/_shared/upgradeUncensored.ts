import {ethers} from "hardhat";
import {ProxyAdmin__factory} from "../../types";
import {COMPOSER_LOGICS, COMPOSER_PROXIES, PROXY_ADMINS} from "./addresses";
import {formatEther} from "ethers/lib/utils";

const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";
const SONEIUM_CHAIN_ID = 1868;

async function main() {
    // L1 signer via hardhat (run with --network mainnet)
    const [_, operator] = await ethers.getSigners();
    const l1Provider = ethers.provider;
    const l2Provider = new ethers.providers.JsonRpcProvider("https://rpc.soneium.org");

    console.log("L1 sender:  ", operator.address);
    console.log("L1 chain ID:", (await l1Provider.getNetwork()).chainId); // should be 1
    console.log("L1 balance: ", formatEther(await operator.getBalance()), "ETH");

    const gasPrice = await l1Provider.getGasPrice();
    console.log("L1 gas price:", gasPrice.toNumber() / 1e9, "gwei");

    const proxyAdmin = PROXY_ADMINS[SONEIUM_CHAIN_ID];
    const composerProxy = COMPOSER_PROXIES[SONEIUM_CHAIN_ID];
    const composerLogic = COMPOSER_LOGICS[SONEIUM_CHAIN_ID];

    console.log("ProxyAdmin:     ", proxyAdmin);
    console.log("Proxy:          ", composerProxy);
    console.log("New logic:      ", composerLogic);

    // Verify ownership on L2 before attempting
    const proxy = ProxyAdmin__factory.connect(proxyAdmin, l2Provider);
    const owner = await proxy.owner();
    console.log("ProxyAdmin owner:", owner);
    if (owner.toLowerCase() !== operator.address.toLowerCase()) {
        throw new Error(`Operator ${operator.address} is not the ProxyAdmin owner (${owner})`);
    }

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
    console.log("\nUpgrade forced through. Monitor Soneium for execution.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
