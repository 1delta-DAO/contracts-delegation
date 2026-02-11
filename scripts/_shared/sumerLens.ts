import {ethers} from "hardhat";
import {SumerLens__factory} from "../../types";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Morpho lens");
    const cometLens = await new SumerLens__factory(operator).deploy();

    console.log("lens:", cometLens.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
