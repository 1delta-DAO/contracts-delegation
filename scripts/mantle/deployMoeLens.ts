
import { ethers } from "hardhat";
import { MoeJoeLens__factory } from "../../types";
import { MANTLE_CONFIGS } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("MoeJoeLens__factory deploying")
    const lens = await new MoeJoeLens__factory(operator).deploy(MANTLE_CONFIGS)

    console.log("les:", lens.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
