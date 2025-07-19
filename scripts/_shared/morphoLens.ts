
import { ethers } from "hardhat";
import { MorphoLens__factory } from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("Morpho lens")
    const cometLens = await new MorphoLens__factory(operator).deploy()

    console.log("lens:", cometLens.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
