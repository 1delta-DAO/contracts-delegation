import {ethers} from "hardhat";
import {TakaraLens__factory} from "../../types";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gasPrice", gp.toNumber() / 1e9);

    console.log("Morpho lens");
    const cometLens = await new TakaraLens__factory(operator).deploy(
        "0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE",
        "0xD6a275072dceC8a319c0C7178951A0CF9DCC0447"
    );

    console.log("lens:", cometLens.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
