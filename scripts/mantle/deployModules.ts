
import { ethers } from "hardhat";
import {
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
} from "../../types";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // flash swapper
    const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).deploy()
    await flashBroker.deployed()
    console.log("flashBroker deployed")

    // // lending interactions
    // const lendingInterface = await new DeltaLendingInterfaceMantle__factory(operator).deploy()
    // await lendingInterface.deployed()
    // console.log("lendingInterface deployed")

    console.log("FlashBroker", flashBroker.address)
    // console.log("LendingInterface", lendingInterface.address)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
