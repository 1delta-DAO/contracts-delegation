import { constants } from "ethers"
import { HanaTaiko } from "../addresses/hanaAddresses"
import { TOKENS_TAIKO } from "../addresses/tokens"
import { TaikoLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getHanaDatas() {
    const tokenKeys = Object.keys(HanaTaiko.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: HanaTaiko.A_TOKENS[k],
            debtToken: HanaTaiko.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: TaikoLenderId.HANA
        })
    }
    return params
}

export function getHanaApproveDatas() {
    const tokenKeys = Object.keys(HanaTaiko.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: HanaTaiko.POOL,
        })
    }
    return params
}