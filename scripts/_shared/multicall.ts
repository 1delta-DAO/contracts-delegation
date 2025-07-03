
import { ethers } from "hardhat";
import { UniswapInterfaceMulticall__factory } from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("MC")
    const cometLens = await new UniswapInterfaceMulticall__factory(operator).deploy()

    console.log("address:", cometLens.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
