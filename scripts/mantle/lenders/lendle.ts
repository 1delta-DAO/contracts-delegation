import { constants } from "ethers"
import { LendleMantle } from "../addresses/lendleAddresses"
import { TOKENS_MANTLE } from "../addresses/tokens"
import { MantleLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getLendleDatas() {
    const tokenKeys = Object.keys(LendleMantle.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_MANTLE[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: LendleMantle.A_TOKENS[k],
            debtToken: LendleMantle.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: MantleLenderId.LENDLE
        })
    }
    return params
}

export function getLendleApproveDatas() {
    const tokenKeys = Object.keys(LendleMantle.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_MANTLE[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
             token,
            target: LendleMantle.POOL,
        })
    }
    return params
}