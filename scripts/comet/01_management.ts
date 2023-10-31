
import { ethers } from "hardhat";
import { CometManagementModule__factory } from "../../types";
import { cometBrokerAddresses } from "../../deploy/polygon_addresses"
import { validateAddresses } from "../../utils/types";
import { compoundTokens, cometAddress } from "./cometAddresses";

// const usedMaxFeePerGas = parseUnits('200', 9)
// const usedMaxPriorityFeePerGas = parseUnits('20', 9)

const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas
    // gasLimit: 4000000
}

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 137) throw new Error("invalid chain")

    const proxyAddress = cometBrokerAddresses.BrokerProxy[chainId]

    validateAddresses([
        proxyAddress,
    ])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const management = await new CometManagementModule__factory(operator).attach(proxyAddress)

    const underlyingAddresses = Object.values(compoundTokens[chainId])
    console.log("Assets", underlyingAddresses)

    console.log("set comet", cometAddress[chainId].USDC)
    let tx = await management.addComet(cometAddress[chainId].USDC, 0, opts)
    await tx.wait()

    console.log("approve comet")
    tx = await management.approveComet(underlyingAddresses, 0, opts)
    await tx.wait()

    console.log("completed")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });