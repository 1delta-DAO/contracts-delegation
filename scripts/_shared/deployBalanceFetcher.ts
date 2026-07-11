import { ethers } from "hardhat";
import { BalanceFetcher__factory, DeployFactory__factory } from "../../types";
import { DEPLOY_FACTORY } from "./addresses";
import { keccak256 } from "ethers/lib/utils";

/**
export FACTORY="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export CALLER="0x16c4Dc0f662E2bEceC91fC5E7aeeC6a25684698A"
export INIT_CODE_HASH="0x24e20d66993278d433352377f81583f2d1e2e935ced9f88d9fc4a077d9172a1f"
export GPU_DEVICE=255
export ADDRESS_START_WITH="ba1a"
export ADDRESS_END_WITH="1"
cargo run --release $FACTORY $CALLER $INIT_CODE_HASH $GPU_DEVICE $ADDRESS_START_WITH $ADDRESS_END_WITH
 */

//0x16c4dc0f662e2becec91fc5e7aeec6a25684698ab8b2457e1ea1fd039c69f19c => 0xba1a60c7B0e784Bf25F731Ca9fcA6762fFd63a11

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Get deploy factory");

    const salt = "0x16c4dc0f662e2becec91fc5e7aeec6a25684698ab8b2457e1ea1fd039c69f19c";
    // creation bytecode of the canonical mainnet deployment (0xba1a60c7B0e784Bf25F731Ca9fcA6762fFd63a11)
    // sourced from the original deploy tx 0x0f79692aca05dba3df2f440abb1d8d833d3517812c042f8d27a9c30977258068
    const bytecode =
        "0x6080604052348015600f57600080fd5b506102a08061001f6000396000f3fe60806040523415610034577ff2365b5b0000000000000000000000000000000000000000000000000000000060005260046000fd5b610063565b7f7db491eb0000000000000000000000000000000000000000000000000000000060005260046000fd5b7f70a08231000000000000000000000000000000000000000000000000000000006000526100b6565b8160045260006020600460246000855afa156100b057601f3d11156100b057506004515b92915050565b6044356024358160f01c8260e01c61ffff1692508215811517156100dc576100dc610039565b6014830260148202016004018218156100f7576100f7610039565b604051915060108184020260048402016048018201604052602082524360c01b6040830152604882016014840260040160005b85811015610211576004830192604860148302013560601c90600090815b878110156101cf576044601482028701013560601c600081158015610170578631915061017d565b61017a878461008c565b91505b508061018a5750506101c7565b6dffffffffffffffffffffffffffff8116607084901b6fffff0000000000000000000000000000161760801b895250506010870196506001830192505b600101610148565b5080517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff1661ffff8316601086901b63ffff0000161760e01b179052505060010161012a565b50507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8201166040528281037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc08101602085015283f3fea2646970667358221220e70fe2f286bb2c355aa2e1e9e5742cbd41da375c987f7b85761495dd0efe4dbf64736f6c634300081c0033";
    // BalanceFetcher__factory.bytecode; // <- recompiles to a different metadata hash and won't match 0xba1a8c…
    // console.log("bytecode", bytecode);
    const initCode = keccak256(bytecode);
    console.log("initCode", initCode); // 0x09cb7897c717dbd9ce854f8065845a88cef8502317b4c8f3e2de70b4cbe6d8e5 (paris, 1m steps)

    const deployFactory = await new DeployFactory__factory(operator).attach(DEPLOY_FACTORY);
    const address = await deployFactory.computeAddress(salt, initCode);
    console.log("address", address);
    const estimate = await deployFactory.estimateGas.deploy(salt, bytecode);
    console.log("estimate", estimate);
    const tx = await deployFactory.deploy(salt, bytecode, { gasLimit: estimate.add(100), gasPrice: gp });
    await tx.wait();

    console.log("deployed expected to", address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
