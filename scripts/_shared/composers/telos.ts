import {ethers} from "hardhat";
import {OneDeltaComposerTelosEvm__factory} from "../../../types";
import {Chain} from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.TELOS_EVM_MAINNET) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    const composer = await new OneDeltaComposerTelosEvm__factory(operator).deploy({gasPrice: gp});
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
