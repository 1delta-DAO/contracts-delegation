
import { ethers } from "hardhat";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";
import { ManagementModule__factory } from "../../types";
import { addressesTokensMantle } from "./lendleAddresses";

const underlyings = [
    addressesTokensMantle.USDC,
    addressesTokensMantle.USDT,
    '0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3' // mUSD
]

const stratum3USD = '0xD6F312AA90Ad4C92224436a7A4a648d69482e47e'

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    let tx;
    // get management module
    const management = await new ManagementModule__factory(operator).attach(proxyAddress)

    console.log("est. gas")
    await management.estimateGas.approveAddress(underlyings, stratum3USD)
    console.log("success")
    console.log("Approve stratum3USD")
    tx = await management.approveAddress(underlyings, stratum3USD)
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });