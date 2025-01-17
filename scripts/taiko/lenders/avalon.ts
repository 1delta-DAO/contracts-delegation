import { constants } from "ethers"
import { AvalonTaiko } from "../addresses/avalonAddresses"
import { TOKENS_TAIKO } from "../addresses/tokens"
import { TaikoLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAvalonDatas() {
    const tokenKeys = Object.keys(AvalonTaiko.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: AvalonTaiko.A_TOKENS[k],
            debtToken: AvalonTaiko.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: TaikoLenderId.AVALON
        })
    }
    return params
}

export function getAvalonApproveDatas() {
    const tokenKeys = Object.keys(AvalonTaiko.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_TAIKO[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: AvalonTaiko.POOL,
        })
    }
    return params
}