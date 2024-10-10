
import { ethers } from "hardhat";
import {
    DeltaMetaAggregator__factory,
} from "../../types";

const FIXED_NONCE = 99999999999999;

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    console.log("operator", operator.address, "on", chainId)

    const magwp = await new DeltaMetaAggregator__factory(operator).deploy({ nonce: FIXED_NONCE })
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
