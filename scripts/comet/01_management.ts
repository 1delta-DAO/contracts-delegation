
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

const addresses = cometBrokerAddresses as any
const addressesComet = cometAddress as any

async function main() {


    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    const proxyAddress = addresses.BrokerProxy[chainId]
    // const minimalRouter = addresses.minimalRouter[chainId]

    validateAddresses([
        proxyAddress,
        //  minimalRouter
    ])

    console.log("Operate on", chainId, "by", operator.address)

    // deploy ConfigModule
    const management = await new CometManagementModule__factory(operator).attach(proxyAddress)

    const cometWETH = compoundTokens[chainId][chainId === 80001 || chainId === 137 ? 'WMATIC' : 'WETH']
    console.log("set weth", cometWETH)

    let tx = await management.setNativeWrapper(cometWETH, opts)
    await tx.wait()
    console.log("weth set", cometWETH)

    // tx = await management.setUniswapRouter(minimalRouter, opts)
    // await tx.wait()
    // console.log("router set", minimalRouter)

    const underlyingAddresses = Object.values(compoundTokens[chainId])
    console.log("Assets", underlyingAddresses)

    // console.log("approve router")
    // tx = await management.approveRouter(underlyingAddresses, opts)
    // await tx.wait()

    console.log("set comet", addressesComet[chainId].USDC)
    tx = await management.addComet(addressesComet[chainId].USDC, 0, opts)
    await tx.wait()

    console.log("approve comet")
    tx = await management.approveComet(underlyingAddresses, 0, opts)
    await tx.wait()

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });