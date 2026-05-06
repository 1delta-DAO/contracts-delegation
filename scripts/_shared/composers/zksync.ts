import {ethers} from "hardhat";
import {OneDeltaComposerZkSync__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.ZKSYNC_MAINNET) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();
    console.log("gasPrice", gp.toNumber() / 1e9);

    const balance = await operator.getBalance();
    console.log("balance", ethers.utils.formatEther(balance));

    const dt = new OneDeltaComposerZkSync__factory(operator).getDeployTransaction();
    const gl = await operator.estimateGas(dt);
    console.log("gasLimit", gl.toString());

    const fee = gl.mul(gp);
    console.log("estimated fee (ETH)", ethers.utils.formatEther(fee));
    if (balance.lt(fee)) {
        throw new Error(`insufficient funds: have ${ethers.utils.formatEther(balance)}, need ${ethers.utils.formatEther(fee)}`);
    }

    const composer = await new OneDeltaComposerZkSync__factory(operator).deploy({gasPrice: gp, gasLimit: gl});
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
