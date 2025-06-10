
import { ethers } from "hardhat";
import { FeeOnTransferDetector__factory } from "../../types";

const factory = "0xF38E7c7f8eA779e8A193B61f9155E6650CbAE095"
const isSolidly = false
const codeHash = "0xa856464ae65f7619087bc369daaf7e387dae1e5af69cfa7935850ebf754b04c1"

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("deploy for detector")

    const dt = new FeeOnTransferDetector__factory(operator).getDeployTransaction(factory, codeHash, isSolidly)

    const gl = await operator.estimateGas(dt)

    const detector = await new FeeOnTransferDetector__factory(operator).deploy(factory, codeHash, isSolidly, { gasLimit: gl })

    console.log("detector:", detector.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
