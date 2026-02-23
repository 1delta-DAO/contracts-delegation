import {ethers} from "ethers";
import {OneDeltaComposerSoneium__factory} from "../../../types";

const L1_RPC = process.env.L1_RPC!;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;

// Soneium Mainnet OptimismPortal
const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";

const ADDRESS_ALIAS_OFFSET = "0x1111000000000000000000000000000000001111";

function applyL1ToL2Alias(l1Address: string): string {
    return ethers.utils.getAddress(ethers.BigNumber.from(l1Address).add(ADDRESS_ALIAS_OFFSET).toHexString());
}

async function main() {
    // L1 signer
    const l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC);
    const l1Signer = new ethers.Wallet(PRIVATE_KEY, l1Provider);

    console.log("L1 sender:", l1Signer.address);

    // Build deployment initcode (no send)
    const factory = new OneDeltaComposerSoneium__factory(l1Signer);
    const deployTx = factory.getDeployTransaction();

    if (!deployTx.data) throw new Error("No initcode");

    // Predict L2 contract address
    const l2Deployer = applyL1ToL2Alias(l1Signer.address);
    const l2Nonce = await l1Provider.getTransactionCount(l1Signer.address);

    const predictedAddress = ethers.utils.getContractAddress({
        from: l2Deployer,
        nonce: l2Nonce,
    });

    console.log("Predicted L2 contract address:", predictedAddress);

    // Portal contract
    const portal = new ethers.Contract(PORTAL, ["function depositTransaction(address,uint256,uint64,bool,bytes) payable"], l1Signer);

    console.log("Sending forced deployment via L1...");

    const tx = await portal.depositTransaction(
        ethers.constants.AddressZero, // contract creation
        0, // value
        15_000_000, // L2 gas limit
        true, // isCreation
        deployTx.data, // initcode
        {value: 0}
    );

    console.log("L1 tx hash:", tx.hash);
    await tx.wait();

    console.log("Force deployment submitted.");
    console.log("Contract will appear on Soneium at:");
    console.log(predictedAddress);
}

main().catch(console.error);
