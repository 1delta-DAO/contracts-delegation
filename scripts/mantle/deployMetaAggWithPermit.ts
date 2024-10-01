
import { ethers } from "hardhat";
import {
    DeltaMetaAggregatorWithPermit__factory,
} from "../../types";
import { MANTLE_CONFIGS } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    const magwp = await new DeltaMetaAggregatorWithPermit__factory(operator).deploy(MANTLE_CONFIGS)
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
