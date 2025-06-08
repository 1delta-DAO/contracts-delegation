
import { ethers } from "ethers";
import { getPDDeployCode } from "./aaveV2PDProvider";

/** The address provider for the deployment */
const addressesProvider = "0x4d1227D71e64d79c069221C1f7Ff1a492F0FB133"

/** Deploy an aave v2/3 protocol data provider based on simple bytecode (no explicit contract needed) */
async function main() {
    const provider = new ethers.JsonRpcProvider("https://klaytn.api.onfinality.io/public")
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, provider)
    // const operator = accounts[1]

    console.log("deploy quoter")

    // get the deploy code
    const dt = "0x" + getPDDeployCode(addressesProvider.replace("0x", ""))

    const gl = await operator.estimateGas({ data: dt })

    const gs = await provider.getFeeData()

    const tx = await operator.sendTransaction({ data: dt, gasLimit: gl, gasPrice: gs.gasPrice })

    console.log("tx", tx.hash)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
