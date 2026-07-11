import { ethers } from "hardhat";
import { OneDeltaComposerPharos__factory } from "../../../types";
import { Chain } from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.PHAROS_MAINNET) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    // Buffer the gas price: base fee can rise between fetch and send.
    const gp = (await operator.getGasPrice());

    console.log("gasPrice", gp.toNumber() / 1e9);

    // Estimate the deploy gas explicitly and pass it with a buffer. ethers' automatic
    // gas estimation during deploy() can under-report the code-deposit cost (~24KB
    // runtime => ~4.9M gas just to store), failing with
    // "contract creation code storage out of gas".
    const deployTx = new OneDeltaComposerPharos__factory(operator).getDeployTransaction();
    const gasLimit = (await operator.estimateGas(deployTx)).mul(13).div(10);
    console.log("gasLimit", gasLimit.toString());

    const composer = await new OneDeltaComposerPharos__factory(operator).deploy({ gasPrice: gp, gasLimit });
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
