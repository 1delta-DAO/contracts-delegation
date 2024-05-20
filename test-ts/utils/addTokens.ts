import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { DeltaBrokerProxy__factory, ManagementModule__factory } from "../../types";
import { LENDLE_POOL, LENDLE_A_TOKENS, LENDLE_S_TOKENS, LENDLE_V_TOKENS, addressesTokensMantle } from "../../scripts/mantle/addresses/lendleAddresses";
import { AURELIUS_POOL, AURELIUS_A_TOKENS, AURELIUS_S_TOKENS, AURELIUS_V_TOKENS } from "../../scripts/mantle/addresses/aureliusAddresses";


export async function addMantleLenderTokens(signer: SignerWithAddress, broker: string) {
    const brokerContract = await new DeltaBrokerProxy__factory(signer).attach(broker)

    const management = ManagementModule__factory.createInterface()
    let callsLendle = []

    const assets = Object.keys(addressesTokensMantle)
    for (const key of assets) {
        callsLendle.push(
            management.encodeFunctionData('addGeneralLenderTokens', [
                addressesTokensMantle[key],
                LENDLE_A_TOKENS[key],
                LENDLE_V_TOKENS[key],
                LENDLE_S_TOKENS[key],
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
                AURELIUS_A_TOKENS[key],
                AURELIUS_V_TOKENS[key],
                AURELIUS_S_TOKENS[key],
                1
            ])
        )
    }

    callsAurelius.push(management.encodeFunctionData('approveAddress', [Object.values(addressesTokensMantle), AURELIUS_POOL]))

    await brokerContract.multicall([...callsLendle, ...callsAurelius])
}