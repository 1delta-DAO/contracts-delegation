
import { ethers } from "hardhat";
import { QuoterLight__factory } from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("deploy quoter")

    const dt = new QuoterLight__factory(operator).getDeployTransaction()

    const gl = await operator.estimateGas(dt)

    const oneDeltaManagement = await new QuoterLight__factory(operator).deploy({ gasLimit: gl })

    console.log("quoter:", oneDeltaManagement.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
