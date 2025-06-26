
import { ethers } from "ethers";
import { ProxyAdmin__factory } from "../../../types";
import { Chain } from "@1delta/asset-registry";
import { COMPOSER_LOGICS, COMPOSER_PROXIES, PROXY_ADMINS } from "../addresses";

async function main() {
    const p = new ethers.providers.JsonRpcProvider("https://rpc.mantle.xyz")
    // const accounts = await ethers.getSigners()
    const operator = new ethers.Wallet(process.env.PK_5!, p)
    // const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("operator", operator.address, "on", chainId)

    if (String(chainId) !== Chain.MANTLE) throw new Error("IC")

    const intf = ProxyAdmin__factory.createInterface()
    const data = intf.encodeFunctionData("upgradeAndCall", [
        // @ts-ignore
        COMPOSER_PROXIES[chainId],
        // @ts-ignore
        COMPOSER_LOGICS[chainId],
        "0x"
    ])
    console.log("upgrade")

    await operator.sendTransaction({
        // @ts-ignore
        to: PROXY_ADMINS[chainId],
        data,
        value: 0n
    })

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
