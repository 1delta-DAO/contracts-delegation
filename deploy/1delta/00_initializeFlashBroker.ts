import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
    AaveMarginTraderInit,
    AaveMarginTraderInit__factory,
    ConfigModule__factory,
    ManagementModule__factory,
} from "../../types";
import { ModuleConfigAction, getSelectors } from "../../test-ts/libraries/diamond";
import { addressesAaveATokens, addressesAaveSTokens, addressesAaveVTokens, addressesTokens } from "../../scripts/aaveAddresses";
import { oneInchRouter, paraswapRouter, paraswapTransferProxy } from "../../scripts/miscAddresses";
import { ethers } from "hardhat";


export async function initializeFlashBroker(_chainId: number, signer: SignerWithAddress, deltaProxy: string, aavePool: string, isFork = true, opts: any = {}) {
    const chainId = isFork ? 137 : _chainId
    let tx;

    const dc = await new ConfigModule__factory(signer).attach(deltaProxy)
    const initAAVE = await new AaveMarginTraderInit__factory(signer).deploy(
        opts
    )
    console.log("Deploy config: ", initAAVE.deployTransaction.hash)
    await initAAVE.deployed()
    console.log("initAAVE:", initAAVE.address)

    tx = await dc.configureModules(
        [{
            moduleAddress: initAAVE.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(initAAVE)
        }],
        opts
    )
    await tx.wait()

    // initialize storage
    const dcInit = await new ethers.Contract(deltaProxy, AaveMarginTraderInit__factory.createInterface(), signer) as AaveMarginTraderInit
    tx = await dcInit.initAaveMarginTrader(aavePool)
    await tx.wait()

    console.log("completed initialization of AaveMarginTraderInit")

    // get management module
    const management = await new ManagementModule__factory(signer).attach(deltaProxy)

    const aTokenKeys = Object.keys(addressesAaveATokens).filter(k => Boolean(addressesAaveATokens[k][chainId]))

    const underlyingAddresses = aTokenKeys.map(k => addressesTokens[k][chainId])
    console.log("Assets", underlyingAddresses)

    console.log("add target - 1inch")
    tx = await management.setValidTarget(oneInchRouter[chainId], true)
    await tx.wait()

    console.log("add target - paraswap")
    tx = await management.setValidTarget(paraswapRouter[chainId], true)
    await tx.wait()

    console.log("approve aave pool")
    tx = await management.approveLendingPool(underlyingAddresses, opts)
    await tx.wait()

    console.log("add aave tokens")
    for (let k of aTokenKeys) {
        console.log("add aave tokens a", k)
        const token = addressesTokens[k][chainId]
        tx = await management.addAToken(token, addressesAaveATokens[k][chainId], opts)
        await tx.wait()
        if (addressesAaveSTokens?.[k] && addressesAaveSTokens?.[k]?.[chainId]) {
            console.log("add aave tokens s", k)
            tx = await management.addSToken(token, addressesAaveSTokens[k][chainId], opts)
            await tx.wait()
        } else {
            console.log("No sToken")
        }
        console.log("add aave tokens v", k)
        tx = await management.addVToken(token, addressesAaveVTokens[k][chainId], opts)
        await tx.wait()
        console.log("add aave tokens base", k)

    }
}


export async function addTokens(chainId: number, signer: SignerWithAddress, deltaProxy: string, opts: any = {}) {
    let tx;
    // get management module
    const management = await new ManagementModule__factory(signer).attach(deltaProxy)

    const aTokenKeys = Object.keys(addressesAaveATokens).filter(k => Boolean(addressesAaveATokens[k][chainId]))

    console.log("Assets", aTokenKeys)
    console.log("add aave tokens")
    for (let k of aTokenKeys) {
        console.log("add aave tokens a", k)
        const token = addressesTokens[k][chainId]
        tx = await management.addLenderTokens(
            token,
            addressesAaveATokens[k][chainId],
            addressesAaveVTokens[k][chainId],
            addressesAaveSTokens[k]?.[chainId] ?? ethers.constants.AddressZero,
            opts
        )
        await tx.wait()
        console.log("add aave tokens base", k)

    }
}


export async function approveSpending(chainId: number, signer: SignerWithAddress, deltaProxy: string, opts: any = {}) {
    let tx;
    // get management module
    const management = await new ManagementModule__factory(signer).attach(deltaProxy)

    const aTokenKeys = Object.keys(addressesAaveATokens).filter(k => Boolean(addressesAaveATokens[k][chainId]))
    const underlyingAddresses = aTokenKeys.map(k => addressesTokens[k][chainId])
    console.log("Assets", underlyingAddresses)

    console.log("add target - 1inch")
    tx = await management.setValidTarget(oneInchRouter[chainId], true)
    await tx.wait()

    console.log("add target - paraswap")
    tx = await management.setValidTarget(paraswapRouter[chainId], true)
    await tx.wait()

    console.log("approve aave pool")
    tx = await management.approveLendingPool(underlyingAddresses, opts)
    await tx.wait()

    console.log("Approve 1inch")
    tx = await management.approveAddress(underlyingAddresses, oneInchRouter[chainId])
    await tx.wait()

    console.log("Approve paraswap transfer proxy")
    tx = await management.approveAddress(underlyingAddresses, paraswapTransferProxy[chainId])
    await tx.wait()
}
