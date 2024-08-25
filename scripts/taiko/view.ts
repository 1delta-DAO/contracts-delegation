
import { ethers } from "hardhat";
import { TOKENS_TAIKO } from "./addresses/tokens";
import { ERC20BurnableMock__factory, ERC20__factory, MantleManagementModule__factory } from "../../types";
import { ONE_DELTA_GEN2_ADDRESSES_TAIKO } from "./addresses/oneDeltaAddresses";

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
]
async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 167000) throw new Error("Invalid chain, expected Mantle")

    const proxyAddress = ONE_DELTA_GEN2_ADDRESSES_TAIKO.proxy

    const viewer = await new MantleManagementModule__factory(operator).attach(proxyAddress)

    console.log("Operate on", chainId, "by", operator.address)

    // const pool = await viewer.getLendingPool()
    // const token = await viewer.getAToken(addressesTokensMantle.WMNT)
    // console.log("TOS", pool, token)
    // const usdcContract = await new ERC20BurnableMock__factory(operator).attach(TOKENS_MANTLE.WMNT)
    // const allow = await usdcContract.allowance(proxyAddress, lendlePool)
    // console.log("Allow", allow.toString())

    const agg = aggregatorsTargets[1]
    const isApr = await viewer.getIsValidTarget(agg, agg)
    console.log("isa", isApr)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });