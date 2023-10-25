
import { ethers } from "hardhat";
import { ConfigModule__factory, LensModule__factory, OwnershipModule__factory } from "../types";
import { aaveBrokerAddresses, generalAddresses, uniswapAddresses } from "../deploy/polygon_addresses"
import { validateAddresses } from "../utils/types";
import { aTokens, sTokens, tokens, vTokens } from "./aaveAddresses";

// const usedMaxFeePerGas = parseUnits('200', 9)
// const usedMaxPriorityFeePerGas = parseUnits('20', 9)

const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas
    gasLimit: 3500000
}

const addresses = aaveBrokerAddresses as any
const target = '0xdfF1b98cbFAc68Af1b2722Ed78D6e47AbFb7D8C1'
async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]

    validateAddresses([proxyAddress, target])

    validateAddresses([proxyAddress])

    console.log("Operate on", chainId, "by", operator.address)

    // get broker contract
    const broker = await new ConfigModule__factory(operator).attach(proxyAddress)

    const cut: {
        moduleAddress: string,
        action: any,
        functionSelectors: any[]
    }[] = []

    // get lens to fetch modules
    const lens = await new LensModule__factory(operator).attach(proxyAddress)

    const modules = await lens.moduleAddresses()
    console.log("module addresses",modules)
const cc = await lens.moduleFunctionSelectors('0x507e3ee4585c5FEc453917572bbC8f829DD91a4E')
console.log("SX",cc)
    // const callbackSelectors = await lens.moduleFunctionSelectors(callbackAddress)
    // const marginTradingSelectors = await lens.moduleFunctionSelectors(marginTradingAddress)
    // const moneyMarketSelectors = await lens.moduleFunctionSelectors(moneyMarketAddress)
    // const managementSelectors = await lens.moduleFunctionSelectors(managementAddress)
    // console.log("Ownership transferred!")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });