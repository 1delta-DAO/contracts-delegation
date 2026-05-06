import {ethers} from "hardhat";
import {OneDeltaComposerAbstract__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.ABSTRACT) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();
    console.log("gasPrice", gp.toNumber() / 1e9);

    const dt = new OneDeltaComposerAbstract__factory(operator).getDeployTransaction();
    const gl = await operator.estimateGas(dt);
    console.log("gasLimit", gl.toString());

    const composer = await new OneDeltaComposerAbstract__factory(operator).deploy({gasPrice: gp, gasLimit: gl});
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
