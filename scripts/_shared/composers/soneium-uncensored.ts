import {ethers} from "hardhat";
import {OneDeltaComposerSoneium__factory} from "../../../types";
import {formatEther} from "ethers/lib/utils";

// Soneium Mainnet OptimismPortal (on L1)
const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";

async function main() {
    // L1 signer via hardhat (run with --network mainnet)
    const [_, l1Signer] = await ethers.getSigners();
    const l1Provider = ethers.provider;

    // L2 provider for nonce + gas estimation
    const l2Provider = new ethers.providers.JsonRpcProvider("https://rpc.soneium.org");

    console.log("L1 sender:     ", l1Signer.address);
    console.log("L1 chain ID:   ", (await l1Provider.getNetwork()).chainId); // should be 1
    console.log("L1 balance:    ", formatEther(await l1Signer.getBalance()), "ETH");

    const gasPrice = await l1Provider.getGasPrice();
    console.log("L1 gas price:  ", gasPrice.toNumber() / 1e9, "gwei");

    // Build deployment initcode
    const factory = new OneDeltaComposerSoneium__factory(l1Signer);
    const deployTx = factory.getDeployTransaction();
    if (!deployTx.data) throw new Error("No initcode");

    // EOA → no alias applied on L2
    console.log("\nL1 sender is EOA — msg.sender on L2 will be:", l1Signer.address);

    const l2Nonce = await l2Provider.getTransactionCount(l1Signer.address);
    console.log("L2 nonce:      ", l2Nonce);

    const predictedAddress = ethers.utils.getContractAddress({
        from: l1Signer.address,
        nonce: l2Nonce,
    });
    console.log("Predicted L2 address:", predictedAddress);

    // Check if already deployed
    const existingCode = await l2Provider.getCode(predictedAddress);
    if (existingCode !== "0x") {
        console.log("Contract already deployed at", predictedAddress, "— nothing to do.");
        return;
    }

    // Estimate L2 gas
    let l2GasLimit: number;
    try {
        const l2Estimate = await l2Provider.estimateGas({
            from: l1Signer.address,
            data: deployTx.data,
        });
        l2GasLimit = Math.ceil(l2Estimate.toNumber() * 1.25);
        console.log("L2 gas estimate:", l2Estimate.toString(), "→ using", l2GasLimit);
    } catch (e) {
        console.warn("L2 gas estimation failed, falling back to 5_000_000:", e);
        l2GasLimit = 5_000_000;
    }

    const portal = new ethers.Contract(PORTAL, ["function depositTransaction(address,uint256,uint64,bool,bytes) payable"], l1Signer);

    const boostedGasPrice = gasPrice.mul(150).div(100);

    const l1GasEstimate = await portal.estimateGas.depositTransaction(ethers.constants.AddressZero, 0, l2GasLimit, true, deployTx.data, {value: 0});
    console.log("L1 gas estimate:", l1GasEstimate.toString());
    console.log("Estimated L1 cost:", formatEther(l1GasEstimate.mul(boostedGasPrice)), "ETH");

    console.log("\nSending forced deployment via L1 portal...");

    const tx = await portal.depositTransaction(ethers.constants.AddressZero, 0, l2GasLimit, true, deployTx.data, {gasPrice: boostedGasPrice});

    console.log("L1 tx hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("L1 tx confirmed in block:", receipt.blockNumber);

    console.log("\nForce deployment submitted.");
    console.log("Contract will appear on Soneium at:", predictedAddress);
}

main().catch(console.error);
