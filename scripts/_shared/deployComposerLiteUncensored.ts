import {ethers} from "hardhat";
import {ComposerLite__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {formatEther, keccak256} from "ethers/lib/utils";

// Soneium Mainnet OptimismPortal (on L1)
const PORTAL = "0x88e529a6ccd302c948689cd5156c83d4614fae92";
const ADDRESS_ALIAS_OFFSET = "0x1111000000000000000000000000000000001111";
const SALT = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a8993bf4b0b2513027a0bb675";

function applyL1ToL2Alias(l1Address: string): string {
    return ethers.utils.getAddress(ethers.BigNumber.from(l1Address).add(ADDRESS_ALIAS_OFFSET).toHexString());
}

async function main() {
    // operator is your L1 signer (mainnet account in hardhat config)
    const [_, operator] = await ethers.getSigners();

    const l1Provider = ethers.provider;
    const l2Provider = new ethers.providers.JsonRpcProvider("https://rpc.soneium.org");

    console.log("L1 operator:  ", operator.address);
    console.log("L1 chain ID:  ", (await l1Provider.getNetwork()).chainId); // should be 1
    console.log("L1 balance:   ", formatEther(await operator.getBalance()), "ETH");

    const gasPrice = await l1Provider.getGasPrice();
    console.log("L1 gas price: ", gasPrice.toNumber() / 1e9, "gwei");

    // Build the calldata for deployFactory.deploy(salt, bytecode) on L2
    const bytecode = ComposerLite__factory.bytecode;
    const initCodeHash = keccak256(bytecode);
    console.log("Initcode hash:", initCodeHash);

    const deployFactoryInterface = DeployFactory__factory.createInterface();
    const calldata = deployFactoryInterface.encodeFunctionData("deploy", [SALT, bytecode]);

    // Verify predicted address using L2 provider
    const deployFactory = DeployFactory__factory.connect(DEPLOY_FACTORY, l2Provider);
    const predictedAddress = await deployFactory.computeAddress(SALT, initCodeHash);
    console.log("Predicted L2 address:", predictedAddress);

    // Check if already deployed
    const existingCode = await l2Provider.getCode(predictedAddress);
    if (existingCode !== "0x") {
        console.log("Contract already deployed at", predictedAddress, "— nothing to do.");
        return;
    }

    // Estimate L2 gas for the deployFactory call
    let l2GasLimit: number;
    try {
        const l2Estimate = await l2Provider.estimateGas({
            to: DEPLOY_FACTORY,
            data: calldata,
        });
        l2GasLimit = Math.ceil(l2Estimate.toNumber() * 1.25);
        console.log("L2 gas estimate:", l2Estimate.toString(), "→ using", l2GasLimit);
    } catch (e) {
        console.warn("L2 gas estimation failed, falling back to 5_000_000:", e);
        l2GasLimit = 5_000_000;
    }

    // Portal contract on L1
    const portal = new ethers.Contract(PORTAL, ["function depositTransaction(address,uint256,uint64,bool,bytes) payable"], operator);

    const boostedGasPrice = gasPrice.mul(150).div(100);

    const l1GasEstimate = await portal.estimateGas.depositTransaction(
        DEPLOY_FACTORY, // to: the L2 DeployFactory
        0, // value
        l2GasLimit, // L2 gas limit
        false, // isCreation: false — we're calling an existing contract
        calldata, // encoded deploy(salt, bytecode)
        {value: 0}
    );
    console.log("L1 gas estimate:", l1GasEstimate.toString());
    console.log("Estimated L1 cost:", formatEther(l1GasEstimate.mul(boostedGasPrice)), "ETH");

    console.log("\nSending forced deployment via L1 portal...");

    const tx = await portal.depositTransaction(DEPLOY_FACTORY, 0, l2GasLimit, false, calldata, {gasPrice: boostedGasPrice});

    console.log("L1 tx hash:", tx.hash);
    const receipt = await tx.wait();
    console.log("L1 tx confirmed in block:", receipt.blockNumber);

    const l2Deployer = applyL1ToL2Alias(operator.address);
    console.log("\nForced tx submitted. Monitor L2 for execution:");
    console.log("  L2 msg.sender (aliased):", l2Deployer);
    console.log("  Expect ComposerLite at: ", predictedAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
