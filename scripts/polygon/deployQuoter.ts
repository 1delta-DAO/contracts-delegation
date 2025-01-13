
import { ethers } from "hardhat";
import { QuoterTaiko__factory } from "../../types";
import { getPolygonConfig } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("modules added")
    const quoter = await new QuoterTaiko__factory(operator).deploy(getPolygonConfig())

    console.log("quoter:", quoter.address) // 0xd184c5315B728c1C990f59dDD275c8155f8e255c
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
