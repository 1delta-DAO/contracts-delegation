import {ethers} from "hardhat";
import {BalanceFetcher__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0xab4f5aa319b3db9749b62380b824aae222d76f7082fac718324378460c9c453f"
export GPU_DEVICE=255
export ADDRESS_START_WITH="ba1Fe"
export ADDRESS_END_WITH="0"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698ae64b2a14ba22df039bda0d95 => 0xba1Fec5D36a28Ab8c2863E77a264553F3757c6e0 (1 / 0)

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698ad50b78c7fd63fe0324e4c06b";
    //  deploys to 0xfCa1154C643C32638AEe9a43eeE7f377f515c801
    const bytecode = BalanceFetcher__factory.bytecode;

    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0xab4f5aa319b3db9749b62380b824aae222d76f7082fac718324378460c9c453f (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    // const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    // console.log("estimate", estimate);
    // const tx = await deployFactory.deploy(salt, bytecode, {gasLimit: estimate.add(100), gasPrice: gp});
    // await tx.wait();

    // console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
