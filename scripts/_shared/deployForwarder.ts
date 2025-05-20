
import { ethers } from "hardhat";
import { CallForwarder__factory, DeployFactory__factory } from "../../types";
import { DEPLOY_FACTORY } from "./addresses";
import { keccak256 } from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x6d95759de5f9c1ff23720012281168c1b9cdc928be6790a9eb2efdc32bad0980"
export GPU_DEVICE=255
export ADDRESS_START_WITH="fca11"
export ADDRESS_END_WITH="01"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a790fc4f0e4bd5d03efb132e6 => 0xfca11Db2b5DE60DF9a2C81233333a449983B4101

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    console.log("Get deploy factory")

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a790fc4f0e4bd5d03efb132e6"
    //  deploys to 0xfca11Db2b5DE60DF9a2C81233333a449983B4101
    const bytecode = CallForwarder__factory.bytecode

    const initCode = keccak256(bytecode)
    console.log("initCode", initCode) // 0x6d95759de5f9c1ff23720012281168c1b9cdc928be6790a9eb2efdc32bad0980 (paris, 1m steps)

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
