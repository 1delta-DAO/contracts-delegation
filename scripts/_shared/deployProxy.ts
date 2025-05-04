
import { ethers } from "hardhat";
import {
    TransparentUpgradeableProxy__factory,
} from "../../types";
import { getGasConfig } from "../_utils/getGasConfig";
import { COMPOSER_LOGICS } from "./addresses";

/**
 * Universal gen2 deployer
 */
async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    let config = await getGasConfig(operator, 10, true)
    // config.gasLimit = 10_000_000

    // deploy module config
    const proxy = await new TransparentUpgradeableProxy__factory(operator).deploy(
        // @ts-ignore
        COMPOSER_LOGICS[chainId],
        operator.address,
        { ...config, nonce: nonce++ })
    await proxy.deployed()

    console.log("moduleConfig deployed")

    console.log("deployment complete")
    console.log("======== Addresses =======")
    console.log("proxy:", proxy.address)
    console.log("==========================")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
