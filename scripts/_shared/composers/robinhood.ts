import {ethers} from "hardhat";
import {OneDeltaComposerRobinhood__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.ROBINHOOD_CHAIN) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    // Buffer the gas price: robinhood's base fee moves and a bare getGasPrice()
    // can land below the block base fee ("max fee per gas less than block base fee").
    const gp = (await operator.getGasPrice()).mul(2);

    console.log("gasPrice", gp.toNumber() / 1e9);

    // Estimate the deploy gas explicitly and pass it with a buffer. ethers' automatic
    // gas estimation during deploy() under-reports the code-deposit cost on robinhood
    // (~24KB runtime => ~4.9M gas just to store), which fails with
    // "contract creation code storage out of gas".
    const deployTx = new OneDeltaComposerRobinhood__factory(operator).getDeployTransaction();
    const gasLimit = (await operator.estimateGas(deployTx)).mul(13).div(10);
    console.log("gasLimit", gasLimit.toString());

    const composer = await new OneDeltaComposerRobinhood__factory(operator).deploy({gasPrice: gp, gasLimit});
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
