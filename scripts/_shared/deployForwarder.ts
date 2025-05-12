
import { ethers } from "hardhat";
import { CallForwarder__factory, DeployFactory__factory } from "../../types";
import { DEPLOY_FACTORY } from "./addresses";
import { keccak256 } from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x8757633895e8e012e215fd6d3723aa06ab9c7d233659a957ee8a83e05c39acc3"
export GPU_DEVICE=255
export ADDRESS_START_WITH="fca11"
export ADDRESS_END_WITH="0"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a849b92e0cb5b7703780b288c => 0xfca1137E7b0aE4CbaAd630CcC1C1B24F30c19A30

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("Get deploy factory")

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a849b92e0cb5b7703780b288c"
    //  deploys to 0xfca1137E7b0aE4CbaAd630CcC1C1B24F30c19A30
    const bytecode = CallForwarder__factory.bytecode

    const initCode = keccak256(bytecode)
    console.log("initCode", initCode) // 0x8757633895e8e012e215fd6d3723aa06ab9c7d233659a957ee8a83e05c39acc3 (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY)
    const address = await deployFactory.computeAddress(salt, initCode)
    console.log("address", address)
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
