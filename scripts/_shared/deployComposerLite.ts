import {ethers} from "hardhat";
import {CallForwarder__factory, ComposerLite__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x3960044c5aa1254b1254c3148d53f4f29bf001b5324af0c5a635a4751e0b5e54"
export GPU_DEVICE=255
export ADDRESS_START_WITH="c000001"
export ADDRESS_END_WITH="0"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698ad628c62bbc2b530201e69abd => 0xC000001F1D6b896AbF94927461FeFa52619E0090

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698ad628c62bbc2b530201e69abd";
    //  deploys to 0xC000001F1D6b896AbF94927461FeFa52619E0090
    const bytecode = ComposerLite__factory.bytecode;

    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x16c4dc0f662e2becec91fc5e7aeec6a25684698ad628c62bbc2b530201e69abd (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    console.log("estimate", estimate);
    const tx = await deployFactory.deploy(salt, bytecode, {gasLimit: estimate.mul(105).div(100), gasPrice: gp.mul(100).div(100)});
    await tx.wait();

    console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
