import { MantleManagementModule__factory, MantleManagementModule } from "../../../types";
import { constants } from "ethers";
import { AAVE_V3_A_TOKENS, AAVE_V3_V_TOKENS } from "../addresses/aaveV3Addresses";
import { TOKENS_MANTLE } from "../addresses/tokens";
import { getMantleConfig } from "../utils";
import { ArbitrumLenderId } from "../addresses/lenderIds";

const managementInterface = MantleManagementModule__factory.createInterface()

export function getAddAaveV3Tokens() {
    const tokenKeys = Object.keys(AAVE_V3_A_TOKENS)
    let calls: string[] = []
    for (let k of tokenKeys) {
        console.log("add aave v3 tokens a", k)
        const token = TOKENS_MANTLE[k]
        calls.push(
            managementInterface.encodeFunctionData("addGeneralLenderTokens", [
                token,
                AAVE_V3_A_TOKENS[k],
                AAVE_V3_V_TOKENS[k],
                constants.AddressZero,
                ArbitrumLenderId.AAVE_V3
            ]
            )
        )
    }
    return calls
}


export async function addAaveV3Tokens(manager: MantleManagementModule, nonce: number) {
    const tokenKeys = Object.keys(AAVE_V3_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add aave V3 tokens a", k)
        const token = TOKENS_MANTLE[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            AAVE_V3_A_TOKENS[k],
            AAVE_V3_V_TOKENS[k],
            constants.AddressZero,
            ArbitrumLenderId.AAVE_V3,
            getMantleConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}