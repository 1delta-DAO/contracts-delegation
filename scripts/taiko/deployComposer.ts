
import { ethers } from "hardhat";
import {
    OneDeltaComposerTaiko__factory,
} from "../../types";
import { getTaikoConfig } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    // deploy modules

    // composer
    const composer = await new OneDeltaComposerTaiko__factory(operator).deploy(getTaikoConfig(nonce++))
    await composer.deployed()


    console.log("composer deployed:", composer.address)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
