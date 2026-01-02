import {ethers} from "hardhat";
import {OneDeltaComposerHemi__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";
import {formatEther} from "ethers/lib/utils";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.HEMI_NETWORK) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);
    const gp = await operator.getGasPrice();
    const dt = new OneDeltaComposerHemi__factory(operator).getDeployTransaction();
    const gl = await operator.estimateGas(dt);
    console.log("cost", formatEther(gp.mul(gl)));
    console.log("gasLimit", formatEther(gl));
    const composer = await new OneDeltaComposerHemi__factory(operator).deploy({gasPrice: gp, gasLimit: gl});
    await composer.deployed();

    console.log("deployed to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
