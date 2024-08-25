import { TaikoManagementModule } from "../../../types";
import { MERIDIAN_A_TOKENS, MERIDIAN_S_TOKENS, MERIDIAN_V_TOKENS } from "../addresses/meridianAddresses";
import { constants } from "ethers";
import { HANA_A_TOKENS, HANA_S_TOKENS, HANA_V_TOKENS } from "../addresses/hanaAddresses";
import { TOKENS_TAIKO } from "../addresses/tokens";
import { getTaikoConfig } from "../utils";
import { TaikoLenderId } from "../addresses/lenderIds";


export async function addMeridianTokens(manager: TaikoManagementModule, nonce: number) {
    const tokenKeys = Object.keys(MERIDIAN_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add Meridian tokens a", k)
        const token = TOKENS_TAIKO[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            MERIDIAN_A_TOKENS[k],
            MERIDIAN_V_TOKENS[k],
            MERIDIAN_S_TOKENS?.[k] ?? constants.AddressZero,
            TaikoLenderId.MERIDIAN,
            getTaikoConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}

export async function addHanaTokens(manager: TaikoManagementModule, nonce: number) {
    const tokenKeys = Object.keys(HANA_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add Hana tokens a", k)
        const token = TOKENS_TAIKO[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            HANA_A_TOKENS[k],
            HANA_V_TOKENS[k],
            HANA_S_TOKENS?.[k] ?? constants.AddressZero,
            TaikoLenderId.HANA,
            getTaikoConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}