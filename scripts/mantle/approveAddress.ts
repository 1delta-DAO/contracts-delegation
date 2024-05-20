
import { ethers } from "hardhat";
import { ONE_DELTA_ADDRESSES } from "../../deploy/mantle_addresses";
import { ManagementModule__factory } from "../../types";
import { TOKENS_MANTLE } from "./addresses/tokens";
import { AURELIUS_POOL } from "./addresses/aureliusAddresses";

const underlyings = [
    TOKENS_MANTLE.USDC,
    TOKENS_MANTLE.USDT,
    '0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3' // mUSD
]

const underlyingsEth = [
    TOKENS_MANTLE.WETH,
    TOKENS_MANTLE.METH,
]

const stratum3USD = '0xD6F312AA90Ad4C92224436a7A4a648d69482e47e'
const stratumETH = '0xe8792eD86872FD6D8b74d0668E383454cbA15AFc'

const addressesToApprove = Object.values(TOKENS_MANTLE)
const targetToApprove = AURELIUS_POOL

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("invalid chainId")
    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    let tx;
    // get management module
    const management = await new ManagementModule__factory(operator).attach(proxyAddress)

    console.log("est. gas")
    await management.estimateGas.approveAddress(addressesToApprove, targetToApprove)
    console.log("success")
    console.log("Approve targetToApprove")
    tx = await management.approveAddress(addressesToApprove, targetToApprove)
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });