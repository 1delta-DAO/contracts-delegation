import {ethers} from "hardhat";
import {CallForwarder__factory} from "../../types";

async function main() {
    const accounts = await ethers.getSigners();
    const operator = accounts[1];
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId);

    const gp = await operator.getGasPrice();

    console.log("gp", gp.toNumber() / 1e9);

    console.log("Forwarder irregular");
    const fw = await new CallForwarder__factory(operator).deploy({gasPrice: gp});

    console.log("fw:", fw.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
