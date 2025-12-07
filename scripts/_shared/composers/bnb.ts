import {ethers} from "hardhat";
import {OneDeltaComposerBnb__factory} from "../../../types";
import {Chain} from "@1delta/chain-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.BNB_SMART_CHAIN_MAINNET) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);
    const composer = await new OneDeltaComposerBnb__factory(operator).deploy();
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
