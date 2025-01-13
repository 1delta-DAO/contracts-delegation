import { constants } from "ethers"
import { YldrPolygon } from "../addresses/yldrAddresses"
import { TOKENS_POLYGON } from "../addresses/tokens"
import { PolygonLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getYldrDatas() {
    const tokenKeys = Object.keys(YldrPolygon.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: YldrPolygon.A_TOKENS[k],
            debtToken: YldrPolygon.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: PolygonLenderId.YLDR
        })
    }
    return params
}

export function getYldrApproveDatas() {
    const tokenKeys = Object.keys(YldrPolygon.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
             token,
            target: YldrPolygon.POOL,
        })
    }
    return params
}