
import { ethers } from "hardhat";
import { ManagementModule__factory } from "../types";
import { aaveBrokerAddresses, generalAddresses, uniswapAddresses } from "../deploy/00_addresses"
import { validateAddresses } from "../utils/types";
import { aTokens, sTokens, tokens, vTokens } from "./aaveAddresses";

// const usedMaxFeePerGas = parseUnits('200', 9)
// const usedMaxPriorityFeePerGas = parseUnits('20', 9)

const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas
    // gasLimit: 3500000
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

    // get management module
    const management = await new ManagementModule__factory(operator).attach(proxyAddress)

    // on testnet aave uses a custom WETH

    const underlyingAddresses = Object.values(tokens[chainId])
    console.log("Assets", underlyingAddresses)

    console.log("approve aave pool")
    let tx = await management.approveAAVEPool(underlyingAddresses, opts)
    await tx.wait()

    const keys = Object.keys(tokens[chainId])

    for (let k of keys) {
        console.log("add aave tokens a", k)
        tx = await management.addAToken(tokens[chainId][k], aTokens[chainId][k], opts)
        await tx.wait()
        if (sTokens[chainId][k]) {
            console.log("add aave tokens s", k)
            tx = await management.addSToken(tokens[chainId][k], sTokens[chainId][k], opts)
            await tx.wait()
        } else {
            console.log("No sToken")
        }
        console.log("add aave tokens v", k)
        tx = await management.addVToken(tokens[chainId][k], vTokens[chainId][k], opts)
        await tx.wait()
        console.log("add aave tokens base", k)

    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });