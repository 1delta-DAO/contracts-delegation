
import { ethers } from "hardhat";
import {
    LensModule__factory,
} from "../../types";
import { ONE_DELTA_GEN2_ADDRESSES_POLYGON } from "./addresses/oneDeltaAddresses";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

   
    console.log("modules added")
    const lens = await new LensModule__factory(operator).attach(ONE_DELTA_GEN2_ADDRESSES_POLYGON.proxy)

    const data = await lens.moduleFunctionSelectors(ONE_DELTA_GEN2_ADDRESSES_POLYGON.composerImplementation)

    console.log("data:", data)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
