
import { ethers } from "hardhat";
import { QuoterHemi__factory } from "../../types";
import { Chain } from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== Chain.HEMI_NETWORK) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("modules added")
    const quoter = await new QuoterHemi__factory(operator).deploy()

    console.log("quoter:", quoter.address) // 0xd184c5315B728c1C990f59dDD275c8155f8e255c
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
