import {ethers} from "hardhat";
import {DeployFactory__factory} from "../../../../types";

// deployed on
// hyperevm

async function main() {
    const p = new ethers.providers.JsonRpcProvider("https://rpc.hyperliquid.xyz/evm");
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_6!, p);

    console.log("Deploy factory", await operator.getChainId(), operator.address);
    const deployFactory = await new DeployFactory__factory(operator).getDeployTransaction();
    const data = await operator.sendTransaction(deployFactory); // await deployFactory.deployed();

    console.log("factory:", data);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
