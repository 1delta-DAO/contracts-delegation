
import { ethers } from "hardhat";
import {
    DeltaMetaAggregatorWithPermit__factory,
} from "../../types";
import { MANTLE_CONFIGS } from "./utils";

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
]

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // flash swapper
    const magwp = await new DeltaMetaAggregatorWithPermit__factory(operator).deploy(MANTLE_CONFIGS)
    await magwp.deployed()
    console.log("magwp deployed")

    console.log("magwp", magwp.address)

    await magwp.setValidTarget(aggregatorsTargets[0], aggregatorsTargets[0], true, MANTLE_CONFIGS)
    await magwp.setValidTarget(aggregatorsTargets[1], aggregatorsTargets[1], true, MANTLE_CONFIGS)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
