import { constants } from "ethers"
import { AaveV2Polygon } from "../addresses/aaveV2Addresses"
import { TOKENS_POLYGON } from "../addresses/tokens"
import { PolygonLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAaveV2Datas() {
    const tokenKeys = Object.keys(AaveV2Polygon.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: AaveV2Polygon.A_TOKENS[k],
            debtToken: AaveV2Polygon.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: PolygonLenderId.AAVE_V2
        })
    }
    return params
}

export function getAaveV2ApproveDatas() {
    const tokenKeys = Object.keys(AaveV2Polygon.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: AaveV2Polygon.POOL,
        })
    }
    return params
}