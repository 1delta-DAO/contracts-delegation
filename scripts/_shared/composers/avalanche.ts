
import { ethers } from "hardhat";
import { OneDeltaComposerAvalanche__factory } from "../../../types";
import { Chain } from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.AVALANCHE_C_CHAIN) throw new Error("IC")
    console.log("operator", operator.address, "on", chainId)
    const composer = await new OneDeltaComposerAvalanche__factory(operator).deploy()
    await composer.deployed()

    console.log("deployed expected to", composer.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
