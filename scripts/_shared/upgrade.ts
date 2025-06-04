
import { ethers } from "hardhat";
import {
    ProxyAdmin__factory,
} from "../../types";
import { COMPOSER_LOGICS, COMPOSER_PROXIES, PROXY_ADMINS } from "./addresses";

/**
 * Universal gen2 deployer
 */
async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    const proxy = await new ProxyAdmin__factory(operator).attach(
        // @ts-ignore
        PROXY_ADMINS[chainId]
    )

    const owner = await proxy.owner()

    console.log("owner", owner)

    const gl = await proxy.estimateGas.upgradeAndCall(
        // @ts-ignore
        COMPOSER_PROXIES[chainId],
        // @ts-ignore
        COMPOSER_LOGICS[chainId],
        "0x"
    )

    await proxy.upgradeAndCall(
        // @ts-ignore
        COMPOSER_PROXIES[chainId],
        // @ts-ignore
        COMPOSER_LOGICS[chainId],
        "0x",
        { gasLimit: gl }
    )

    console.log("upgraded")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
