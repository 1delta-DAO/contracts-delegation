
import { ethers } from "hardhat";
import { DeltaMetaAggregator__factory, DeployFactory__factory } from "../../types";
import { DEPLOY_FACTORY } from "./addresses";
import { keccak256 } from "ethers/lib/utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("Get deploy factory")
    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY)

    const salt = "0xad6a484ab655aad350e03095cbc2a6d0f320568c0f050656c4ae543655107129"
    //  deploys to 0xDDDD191F453A387E3D2bB594E657A6D8c8c6D400
    const bytecode = await new DeltaMetaAggregator__factory(operator).bytecode

    const initCode = keccak256(bytecode)
    console.log("initCode", initCode) // 0xe677ed9859bfe2e1a4f4306d6d04b99e578512e8e754b1a66ec6917aaf0d0f54 (paris, 1m steps)
    const address = await deployFactory.computeAddress(salt, initCode)
    const estimate = await deployFactory.estimateGas.deploy(salt, bytecode)
    console.log("estimate", estimate)
    const tx = await deployFactory.deploy(salt, bytecode, { gasLimit: estimate.add(100) })
    await tx.wait()

    console.log("deployed expected to", address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
