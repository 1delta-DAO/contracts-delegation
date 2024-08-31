
import { ethers } from "hardhat";
import { OneDeltaQuoterTaiko__factory } from "../../types";
import { TAIKO_CONFIGS } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("modules added")
    const quoter = await new OneDeltaQuoterTaiko__factory(operator).deploy(TAIKO_CONFIGS)

    console.log("quoter:", quoter.address) // 0xf9438f2b1c63D8dAC24311256F5483D7f7575863
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
