import {ethers} from "hardhat";
import {CallForwarder__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0xc2c9ab00fa915409071ea6dc4064f5dbf00112843be430bfb721e57f4c7e3414"
export GPU_DEVICE=255
export ADDRESS_START_WITH="fca11"
export ADDRESS_END_WITH="03"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a9c651296615ea600372a78a5 => 0xfCa11d8c816f8E52F55D5d9858dEEe78F152d903 (1 / 0)

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a9c651296615ea600372a78a5";
    //  deploys to 0xfCa11d8c816f8E52F55D5d9858dEEe78F152d903
    const bytecode = CallForwarder__factory.bytecode;

    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x6d95759de5f9c1ff23720012281168c1b9cdc928be6790a9eb2efdc32bad0980 (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    console.log("estimate", estimate);
    const tx = await deployFactory.deploy(salt, bytecode, {gasLimit: estimate.add(100), gasPrice: gp});
    await tx.wait();

    console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
