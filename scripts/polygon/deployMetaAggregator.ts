
import { ethers } from "hardhat";
import {
    DeltaMetaAggregator__factory,
} from "../../types";
import { getPolygonConfig } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    const magwp = await new DeltaMetaAggregator__factory(operator).deploy(getPolygonConfig(nonce++))
    await magwp.deployed()
    console.log("magwp deployed")

    console.log("magwp", magwp.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
