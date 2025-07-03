
import { ethers } from "ethers";
import { OneDeltaComposerMantle__factory } from "../../../types";

async function main() {
    const p = new ethers.providers.JsonRpcProvider("https://rpc.mantle.xyz")
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, p)
    // const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("deploy composer")

    const dt = new OneDeltaComposerMantle__factory(operator).getDeployTransaction()

    const gl = await operator.estimateGas(dt)


    const gs = await p.getGasPrice()


    await operator.sendTransaction({ ...dt, gasLimit: gl, gasPrice: gs })

    // const oneDeltaManagement = await new QuoterLight__factory(operator).deploy()

    // console.log("quoter:", oneDeltaManagement.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
