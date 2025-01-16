
import { ethers } from "hardhat";
import { CometLens__factory } from "../../types";
import { ARBITRUM_CONFIGS } from "../_utils/getGasConfig";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 42161) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("Comet lens")
    const cometLens = await new CometLens__factory(operator).deploy(ARBITRUM_CONFIGS)

    console.log("quoter:", cometLens.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
