
import { ethers } from "hardhat";
import { LensModule__factory, ManagementModule__factory, MarginTradeDataViewerModule__factory } from "../types";
import { aaveBrokerAddresses } from "../deploy/00_addresses"
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

async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    const minimalRouter = addresses.minimalRouter[chainId]

    validateAddresses([proxyAddress, minimalRouter])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const management = await new MarginTradeDataViewerModule__factory(operator).attach(proxyAddress)


    const keys = ['GHO'] // Object.keys(tokens[chainId])

    for (let k of keys) {
        const a = await management.getAToken(tokens[chainId][k])
        let s;
        if (sTokens[chainId][k]) {
            s = await management.getSToken(tokens[chainId][k])

        } else {
            console.log("No sToken")
        }
        const v = await management.getVToken(tokens[chainId][k])

        console.log("add aave tokens base", tokens[chainId][k], a, s, v)

    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });