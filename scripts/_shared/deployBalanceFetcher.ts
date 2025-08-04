import {ethers} from "hardhat";
import {CallForwarder__factory, DeployFactory__factory} from "../../types";
import {DEPLOY_FACTORY} from "./addresses";
import {keccak256} from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x800c91cb77f48acac95e2f8fa5bcc201492e56114eeedf360962b1a4dd540524"
export GPU_DEVICE=255
export ADDRESS_START_WITH="fca11"
export ADDRESS_END_WITH="01"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

// 0x16c4dc0f662e2becec91fc5e7aeec6a25684698ae4231e242c5edf00c3a0096c => 0xfCa1154C643C32638AEe9a43eeE7f377f515c801

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    console.log("Get deploy factory");

    const salt = "0x03953645a4b9a929be6f9a030608d1cfa9c2f2ea57432d3e72a3ef278de9fca5";
    //  deploys to 0xfCa1154C643C32638AEe9a43eeE7f377f515c801
    const bytecode =
        "0x6080604052348015600f57600080fd5b506102788061001f6000396000f3fe60806040523415610034577ff2365b5b0000000000000000000000000000000000000000000000000000000060005260046000fd5b610063565b7f7db491eb0000000000000000000000000000000000000000000000000000000060005260046000fd5b7f70a08231000000000000000000000000000000000000000000000000000000006000526100eb565b6000826004526020600460246000855afa50600451905092915050565b60006dffffffffffffffffffffffffffff831661ffff831660701b1760801b905092915050565b600061ffff831661ffff831660101b1760e01b905092915050565b6044356024358160f01c8260e01c61ffff168015821517156101105761010f610039565b5b60148102601483020160040183181561012c5761012b610039565b5b60405160108383020260048302016048018101604052602081524360c01b6040820152604881016014830260040160005b8481101561022557601481026004016044013560601c60008460048601955060005b898110156101e9576014810286016044013560601c60008115600081146101a957863191506101b6565b6101b3878461008c565b91505b50806101c35750506101de565b6101cd81846100a9565b895260108901985060018501945050505b60018101905061017f565b507bffffffffffffffffffffffffffffffffffffffffffffffffffffffff81511661021483866100d0565b17815250505060018101905061015d565b50601f19601f830116604052604083830303602084015282820383f3fea26469706673582212206404b931d4f67d53557dcc964c64b1371c6d95d8646bb8b01240fbe9d0d358fc64736f6c634300081e0033";

    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x6d95759de5f9c1ff23720012281168c1b9cdc928be6790a9eb2efdc32bad0980 (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    console.log("estimate", estimate);
    const tx = await deployFactory.deploy(salt, bytecode, {gasLimit: estimate.add(100)});
    await tx.wait();

    console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
