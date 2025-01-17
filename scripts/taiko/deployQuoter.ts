
import { ethers } from "hardhat";
import { QuoterTaiko__factory } from "../../types";
import { TAIKO_CONFIGS } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 167000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("modules added")
    const quoter = await new QuoterTaiko__factory(operator).deploy(TAIKO_CONFIGS)

    console.log("quoter:", quoter.address) // 0xd184c5315B728c1C990f59dDD275c8155f8e255c
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
