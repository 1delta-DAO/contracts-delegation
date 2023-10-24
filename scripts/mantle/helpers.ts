import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    ManagementModule__factory,
} from "../../types";
import { addressesTokensMantle, addressesLendleATokens, addressesLendleSTokens, addressesLendleVTokens } from "./lendleAddresses";
import { constants } from "ethers";
import { setTimeout } from "timers/promises";

export async function addTokens(chainId: number, signer: SignerWithAddress, deltaProxy: string, opts: any = {}) {
    let tx;
    // get management module
    const management = await new ManagementModule__factory(signer).attach(deltaProxy)

    const aTokenKeys = Object.keys(addressesLendleATokens).filter(k => Boolean(addressesLendleATokens[k]))

    console.log("Assets", aTokenKeys)
    console.log("add lendle tokens")
    for (let k of aTokenKeys) {
        console.log("add lendle tokens a", k)
        const token = addressesTokensMantle[k]
        tx = await management.addLenderTokens(
            token,
            addressesLendleATokens[k],
            addressesLendleVTokens[k],
            addressesLendleSTokens?.[k] ?? constants.AddressZero,
            opts)
        await tx.wait()
        console.log("add lendle tokens base", k)
        await setTimeout(5000);

    }
}


export async function approveSpending(chainId: number, signer: SignerWithAddress, deltaProxy: string, opts: any = {}) {
    let tx;
    // get management module
    const management = await new ManagementModule__factory(signer).attach(deltaProxy)

    const aTokenKeys = Object.keys(addressesLendleATokens).filter(k => Boolean(addressesLendleATokens[k]))
    const underlyingAddresses = aTokenKeys.map(k => addressesTokensMantle[k])
    console.log("Assets", underlyingAddresses)
    console.log("approve lendle pool")
    tx = await management.approveLendingPool(underlyingAddresses, opts)
    await tx.wait()

}
