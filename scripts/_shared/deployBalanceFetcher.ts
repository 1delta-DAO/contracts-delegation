import {ethers} from "hardhat";
import {BalanceFetcher__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x0be0346605c8e3521fde7695446e07497c57526e3ef6fbe0de7cc5d9f6af853d"
export GPU_DEVICE=255
export ADDRESS_START_WITH="ba1a"
export ADDRESS_END_WITH="0"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698a61c5c8b82f65f5038849eb5e => 0xba1a8c699aCb7938e76B062673e00c9b56382310 (1 / 0)

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698a61c5c8b82f65f5038849eb5e";
    //  deploys to 0xfCa1154C643C32638AEe9a43eeE7f377f515c801
    const bytecode = BalanceFetcher__factory.bytecode;
    // console.log("bytecode", bytecode);
    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x09cb7897c717dbd9ce854f8065845a88cef8502317b4c8f3e2de70b4cbe6d8e5 (paris, 1m steps)

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
