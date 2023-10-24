
import { ethers } from "hardhat";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses"
import { validateAddresses } from "../../utils/types";
import { addTokens, approveSpending } from "./helpers";


async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("Invalid chain, expected Mantle")

    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    validateAddresses([proxyAddress])

    console.log("Operate on", chainId, "by", operator.address)

    await addTokens(chainId, operator, proxyAddress, {})

    await approveSpending(chainId, operator, proxyAddress, {})
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });