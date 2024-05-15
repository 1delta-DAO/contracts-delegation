
import { ethers } from "hardhat";
import { lendleBrokerAddresses } from "../../deploy/mantle_addresses";
import { DeltaBrokerProxy__factory, DeltaFlashAggregatorMantle__factory, DeltaLendingInterfaceMantle__factory, OneDeltaQuoterMantle__factory } from "../../types";
import { addressesTokensMantle } from "./lendleAddresses";
import { encodeAggregatorPathEthers, encodeQuoterPathEthers } from "../../test-ts/1delta/shared/aggregatorPath";
import { formatEther, parseUnits, solidityPack } from "ethers/lib/utils";

const WETH = addressesTokensMantle.WETH
const mETH = addressesTokensMantle.METH
const interf = DeltaFlashAggregatorMantle__factory.createInterface()
const interfLender = DeltaLendingInterfaceMantle__factory.createInterface()
const QUOTER = "0x4cA44D7B1e4310959CFCb4b22228237FF65915f1"

// npx hardhat run scripts/mantle/arbtStratum.ts --network mantle

const indexes = {
    [WETH]: 0,
    [mETH]: 1
}

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[0]

    const chainId = await operator.getChainId();
    console.log("op", operator.address)
    if (chainId !== 5000) throw new Error("invalid chainId")

    const quoter = await new OneDeltaQuoterMantle__factory(operator).attach(QUOTER)
    const proxyAddress = lendleBrokerAddresses.BrokerProxy[chainId]

    const pathTokens = [mETH, WETH, mETH]
    const fees = [100, 2]
    const pids = [4, 103]
    const flags = [0, 0]
    const path = encodeQuoterPathEthers(pathTokens, fees, pids)

    const amount = parseUnits('0.1', 18)
    const quote = await quoter.callStatic.quoteExactInput(path, amount)

    console.log(formatEther(quote))

    // const multicaller = await new DeltaBrokerProxy__factory(operator).attach(proxyAddress)

    // const pathSwap = encodeAggregatorPathEthers(pathTokens, fees as any, flags, pids, 99)
    // const swap = interf.encodeFunctionData(
    //     "flashSwapExactIn", [
    //     amount,
    //     amount,
    //     pathSwap
    // ]
    // )

    // const sweep = interfLender.encodeFunctionData(
    //     "sweep", [
    //     WETH,
    // ])

    // if (quote.gt(100000)) {
    //     await multicaller.connect(operator).multicall([
    //         swap,
    //         sweep
    //     ])
    // }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });