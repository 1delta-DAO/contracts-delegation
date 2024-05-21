
import { ethers } from "hardhat";
import {
    DeltaFlashAggregatorMantle__factory,
    DeltaLendingInterfaceMantle__factory,
    LendleFlashModule__factory,
    ManagementModule__factory,
} from "../../types";
import { MANTLE_CONFIGS } from "./utils";

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // flash swapper
    // const flashBroker = await new DeltaFlashAggregatorMantle__factory(operator).deploy(MANTLE_CONFIGS)
    // await flashBroker.deployed()
    // console.log("flashBroker deployed")

    // flash module
    // const lendleFlashModule = await new LendleFlashModule__factory(operator).deploy(MANTLE_CONFIGS)
    // await lendleFlashModule.deployed()
    // console.log("lendleFlashModule deployed")


    // lending interactions
    const lendingInterface = await new DeltaLendingInterfaceMantle__factory(operator).deploy(MANTLE_CONFIGS)
    await lendingInterface.deployed()
    console.log("lendingInterface deployed")


    // lending interactions
    const management = await new ManagementModule__factory(operator).deploy(MANTLE_CONFIGS)
    await management.deployed()
    console.log("management deployed")


    // console.log("FlashBroker", flashBroker.address)
    console.log("LendingInterface", lendingInterface.address)
    console.log("management", management.address)
    // console.log("lendleFlashModule", lendleFlashModule.address)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
