
import { ethers } from "hardhat";
import { OwnershipModule__factory } from "../types";
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

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const management = await new OwnershipModule__factory(operator).attach(proxyAddress)

    const tx = await management.transferOwnership(target)
    await tx.wait()

    console.log("Ownership transferred!")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });