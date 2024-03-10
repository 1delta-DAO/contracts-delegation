import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DeltaBrokerProxy__factory, ManagementModule__factory } from "../../types";
import { LENDLE_POOL, addressesLendleATokens, addressesLendleSTokens, addressesLendleVTokens, addressesTokensMantle } from "../../scripts/mantle/lendleAddresses";
import { AURELIUS_POOL, addressesAureliusATokens, addressesAureliusSTokens, addressesAureliusVTokens } from "../../scripts/mantle/aureliusAddresses";


export async function addMantleLenderTokens(signer: SignerWithAddress, broker: string) {
    const brokerContract = await new DeltaBrokerProxy__factory(signer).attach(broker)

    const management = ManagementModule__factory.createInterface()
    let callsLendle = []

    const assets = Object.keys(addressesTokensMantle)
    for (const key of assets) {
        callsLendle.push(
            management.encodeFunctionData('addGeneralLenderTokens', [
                addressesTokensMantle[key],
                addressesLendleATokens[key],
                addressesLendleVTokens[key],
                addressesLendleSTokens[key],
                0
            ])
        )
    }
    callsLendle.push(management.encodeFunctionData('approveAddress', [Object.values(addressesTokensMantle), LENDLE_POOL]))
    let callsAurelius = []
    for (const key of assets) {
        callsAurelius.push(
            management.encodeFunctionData('addGeneralLenderTokens', [
                addressesTokensMantle[key],
                addressesAureliusATokens[key],
                addressesAureliusVTokens[key],
                addressesAureliusSTokens[key],
                1
            ])
        )
    }

    callsAurelius.push(management.encodeFunctionData('approveAddress', [Object.values(addressesTokensMantle), AURELIUS_POOL]))

    await brokerContract.multicall([...callsLendle, ...callsAurelius])
}