import { constants } from "ethers"
import { YldrArbitrum } from "../addresses/yldrAddresses"
import { TOKENS_ARBITRUM } from "../addresses/tokens"
import { ArbitrumLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getYldrDatas() {
    const tokenKeys = Object.keys(YldrArbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            underlying: token,
            collateralToken: YldrArbitrum.A_TOKENS[k],
            debtToken: YldrArbitrum.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.YLDR
        })
    }
    return params
}

export function getYldrApproveDatas() {
    const tokenKeys = Object.keys(YldrArbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
             token,
            target: YldrArbitrum.POOL,
        })
    }
    return params
}