import { constants } from "ethers"
import { TakoTakoTaiko } from "../addresses/takoTakoAddresses"
import { TOKENS_TAIKO } from "../addresses/tokens"
import { TaikoLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getTakoTakoDatas() {
    const tokenKeys = Object.keys(TakoTakoTaiko.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: TakoTakoTaiko.A_TOKENS[k],
            debtToken: TakoTakoTaiko.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: TaikoLenderId.TAKOTAKO
        })
    }
    return params
}

export function getTakoTakoApproveDatas() {
    const tokenKeys = Object.keys(TakoTakoTaiko.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: TakoTakoTaiko.POOL,
        })
    }
    return params
}