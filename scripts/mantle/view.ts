
import { ethers } from "hardhat";
import { ONE_DELTA_ADDRESSES, lendlePool } from "../../deploy/mantle_addresses"
import { TOKENS_MANTLE } from "./addresses/tokens";
import { ERC20BurnableMock__factory, ERC20__factory, ManagementModule__factory } from "../../types";


async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("Invalid chain, expected Mantle")

    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    const viewer = await new ManagementModule__factory(operator).attach(proxyAddress)

    console.log("Operate on", chainId, "by", operator.address)

    // const pool = await viewer.getLendingPool()
    // const token = await viewer.getAToken(addressesTokensMantle.WMNT)
    // console.log("TOS", pool, token)
    const usdcContract = await new ERC20BurnableMock__factory(operator).attach(TOKENS_MANTLE.WMNT)
    const allow = await usdcContract.allowance(proxyAddress, lendlePool)
    console.log("Allow", allow.toString())
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });