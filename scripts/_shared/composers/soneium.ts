import {ethers} from "hardhat";
import {OneDeltaComposerSoneium__factory} from "../../../types";
import {Chain} from "@1delta/asset-registry";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    if (String(chainId) !== Chain.SONEIUM) throw new Error("IC");
    console.log("operator", operator.address, "on", chainId);
    const composer = await new OneDeltaComposerSoneium__factory(operator).deploy();
    await composer.deployed();

    console.log("deployed expected to", composer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
