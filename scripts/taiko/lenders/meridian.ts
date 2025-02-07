import { constants } from "ethers"
import { MeridianTaiko } from "../addresses/meridianAddresses"
import { TOKENS_TAIKO } from "../addresses/tokens"
import { TaikoLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getMeridianDatas() {
    const tokenKeys = Object.keys(MeridianTaiko.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: MeridianTaiko.A_TOKENS[k],
            debtToken: MeridianTaiko.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: TaikoLenderId.MERIDIAN
        })
    }
    return params
}

export function getMeridianApproveDatas() {
    const tokenKeys = Object.keys(MeridianTaiko.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: MeridianTaiko.POOL,
        })
    }
    return params
}