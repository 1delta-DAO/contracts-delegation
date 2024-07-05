import { MantleManagementModule } from "../../../types";
import { constants } from "ethers";
import { TOKENS_POLYGON } from "../addresses/tokens";
import { getPolygonConfig } from "../utils";
import { AAVE_V3_A_TOKENS, AAVE_V3_S_TOKENS, AAVE_V3_V_TOKENS } from "../addresses/aaveV3Addresses";
import { LenderIdsPolygon } from "../addresses/lenderIds";
import { AAVE_V2_A_TOKENS, AAVE_V2_S_TOKENS, AAVE_V2_V_TOKENS } from "../addresses/aaveV2Addresses";
import { YLDR_A_TOKENS, YLDR_V_TOKENS } from "../addresses/yldrAddresses";


export async function addAaveV3Tokens(manager: MantleManagementModule, nonce: number) {
    const tokenKeys = Object.keys(AAVE_V3_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add aave v3 tokens a", k)
        const token = TOKENS_POLYGON[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            AAVE_V3_A_TOKENS[k],
            AAVE_V3_V_TOKENS[k],
            AAVE_V3_S_TOKENS?.[k] ?? constants.AddressZero,
            LenderIdsPolygon.AAVE_V3,
            getPolygonConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}

export async function addAaveV2Tokens(manager: MantleManagementModule, nonce: number) {
    const tokenKeys = Object.keys(AAVE_V2_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add aave v2 tokens a", k)
        const token = TOKENS_POLYGON[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            AAVE_V2_A_TOKENS[k],
            AAVE_V2_V_TOKENS[k],
            AAVE_V2_S_TOKENS?.[k] ?? constants.AddressZero,
            LenderIdsPolygon.AAVE_V2,
            getPolygonConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}


export async function addYldrTokens(manager: MantleManagementModule, nonce: number) {
    const tokenKeys = Object.keys(YLDR_A_TOKENS)
    for (let k of tokenKeys) {
        console.log("add yldr tokens a", k)
        const token = TOKENS_POLYGON[k]
        const tx = await manager.addGeneralLenderTokens(
            token,
            YLDR_A_TOKENS[k],
            YLDR_V_TOKENS[k],
            constants.AddressZero,
            LenderIdsPolygon.YLDR,
            getPolygonConfig(nonce++)
        )
        await tx.wait()
    }
    return nonce
}