
import { ethers } from "hardhat";
import { OwnershipModule__factory } from "../../types";
import { cometBrokerAddresses } from "../../deploy/00_addresses"
import { validateAddresses } from "../../utils/types";
import { compoundTokens, cometAddress } from "./cometAddresses";

// const usedMaxFeePerGas = parseUnits('200', 9)
// const usedMaxPriorityFeePerGas = parseUnits('20', 9)

const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas
    gasLimit: 4000000
}

const addresses = cometBrokerAddresses as any
const addressesComet = cometAddress as any
const target = ''

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