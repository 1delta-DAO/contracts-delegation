import { constants } from "ethers"
import { AaveV3Polygon } from "../addresses/aaveV3Addresses"
import { TOKENS_POLYGON } from "../addresses/tokens"
import { PolygonLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAaveDatas() {
    const tokenKeys = Object.keys(AaveV3Polygon.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: AaveV3Polygon.A_TOKENS[k],
            debtToken: AaveV3Polygon.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: PolygonLenderId.AAVE_V3
        })
    }
    return params
}

export function getAaveApproveDatas() {
    const tokenKeys = Object.keys(AaveV3Polygon.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_POLYGON[k]
        if (!token) throw new Error("token not defined:" + k)
        params.push({
            token,
            target: AaveV3Polygon.POOL,
        })
    }
    return params
}