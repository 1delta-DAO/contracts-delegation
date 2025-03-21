
import { ethers } from "hardhat";
import { QuoterArbitrum__factory } from "../../types";
import { ARBITRUM_CONFIGS } from "../_utils/getGasConfig";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 42161) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    console.log("deploy quoter")
    const oneDeltaManagement = await new QuoterArbitrum__factory(operator).deploy(ARBITRUM_CONFIGS)

    console.log("quoter:", oneDeltaManagement.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
