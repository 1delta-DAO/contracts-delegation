
import { ethers } from "hardhat";
import { aaveBrokerAddresses } from "../deploy/polygon_addresses"
import { validateAddresses } from "../utils/types";
import { addTokens } from "../deploy/1delta/00_initializeFlashBroker";


const usedMaxFeePerGas = 270_000_000_000
const usedMaxPriorityFeePerGas = 170_000_000_000

const opts = {
    maxFeePerGas: usedMaxFeePerGas,
    maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasLimit: 4_500_000
}


const addresses = aaveBrokerAddresses as any

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]

    validateAddresses([proxyAddress])

    console.log("Operate on", chainId, "by", operator.address)

    await addTokens(chainId, operator, proxyAddress, opts)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });