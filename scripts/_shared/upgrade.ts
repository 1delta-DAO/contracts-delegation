
import { ethers } from "hardhat";
import {
    TransparentUpgradeableProxy__factory,
} from "../../types";
import { COMPOSER_LOGICS, COMPOSER_PROXIES } from "./addresses";

/**
 * Universal gen2 deployer
 */
async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    const proxy = await new TransparentUpgradeableProxy__factory(operator).attach(
        // @ts-ignore
        COMPOSER_PROXIES[chainId]
    )

    await proxy.upgradeTo(
        // @ts-ignore
        COMPOSER_LOGICS[chainId]
    )

    console.log("upgraded")

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
