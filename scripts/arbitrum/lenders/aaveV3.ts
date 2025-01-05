import { constants } from "ethers"
import { AaveV3Arbitrum } from "../addresses/aaveV3Addresses"
import { TOKENS_ARBITRUM } from "../addresses/tokens"
import { ArbitrumLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAaveDatas() {
    const tokenKeys = Object.keys(AaveV3Arbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
            underlying: token,
            collateralToken: AaveV3Arbitrum.A_TOKENS[k],
            debtToken: AaveV3Arbitrum.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.AAVE_V3
        })
    }
    return params
}

export function getAaveApproveDatas() {
    const tokenKeys = Object.keys(AaveV3Arbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        if(!token) throw new Error("token not defined:" + k)
        params.push({
             token,
            target: AaveV3Arbitrum.POOL,
        })
    }
    return params
}