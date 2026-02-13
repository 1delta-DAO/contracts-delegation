import {ethers} from "hardhat";
import {CallForwarder__factory, ComposerLite__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x2484a7cfb0caa9747235ec6213aeb465f5152d72a3fce5160229ed4c9872822d"
export GPU_DEVICE=255
export ADDRESS_START_WITH="c000001"
export ADDRESS_END_WITH="0"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a8ce96e42a702da02028efb08 => 0xC000001862CB86b42cCe88BebfDCC37fbA7FE650 (3 / 2)

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a8ce96e42a702da02028efb08";
    //  deploys to 0xfCa11b85ac641f1ba215259566d579A45519e506
    const bytecode = ComposerLite__factory.bytecode;

    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a8ce96e42a702da02028efb08 (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    // const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    // console.log("estimate", estimate);
    // const tx = await deployFactory.deploy(salt, bytecode, {gasLimit: estimate.add(100), gasPrice: gp.mul(100)});
    // await tx.wait();

    // console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
