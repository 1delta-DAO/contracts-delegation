
import { ethers } from "hardhat";
import { OneDeltaComposerMantle__factory } from "../../types";
import { ONE_DELTA_GEN2_ADDRESSES } from "./addresses/oneDeltaAddresses";
import { getArbitrumConfig } from "./utils";

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("Invalid chain, expected Mantle")

    const proxyAddress = ONE_DELTA_GEN2_ADDRESSES.proxy

    const composer = await new OneDeltaComposerMantle__factory(operator).attach(proxyAddress)

    console.log("Operate on", chainId, "by", operator.address)

    const sweepTypes = [
        "uint8",
        "address",
        "address",
        "uint8",
        "uint112",
    ]

    const token = "0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9" // zero for native
    const sweepType = 0 // balance and validation against amount
    const amount = 0n // we just sweep the entire balance and never revert
    const sweepCall = ethers.utils.solidityPack(
        sweepTypes,
        [
            "0x22", // instruction sweep
            token,
            operator.address, // receiver
            sweepType,
            amount
        ]
    )
    console.log("sweepCall", sweepCall)
    const gasLimit = await composer.estimateGas.deltaCompose(sweepCall)
    console.log("GL", gasLimit)
    const tx = await composer.deltaCompose(sweepCall, { ...getArbitrumConfig(nonce++), gasLimit: gasLimit.mul(11).div(10) })
    console.log("hash", tx.hash)
    await tx.wait()
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });