import { constants } from "ethers"
import { AurelisuMantle } from "../addresses/aureliusAddresses"
import { TOKENS_MANTLE } from "../addresses/tokens"
import { MantleLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAureliusDatas() {
    const tokenKeys = Object.keys(AurelisuMantle.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_MANTLE[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: AurelisuMantle.A_TOKENS[k],
            debtToken: AurelisuMantle.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: MantleLenderId.AURELIUS
        })
    }
    return params
}

export function getAureliusApproveDatas() {
    const tokenKeys = Object.keys(AurelisuMantle.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_MANTLE[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
             token,
            target: AurelisuMantle.POOL,
        })
    }
    return params
}