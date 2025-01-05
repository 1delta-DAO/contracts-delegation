import { constants } from "ethers"
import { VenusArbitrum, VenusETHArbitrum } from "../addresses/venusAddresses"
import { TOKENS_ARBITRUM } from "../addresses/tokens"
import { ArbitrumLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getVenusDatas() {
    const tokenKeys = Object.keys(VenusArbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            underlying: token,
            collateralToken: VenusArbitrum.A_TOKENS[k],
            debtToken: constants.AddressZero,
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.VENUS
        })
    }
    return params
}

export function getVenusApproveDatas() {
    const tokenKeys = Object.keys(VenusArbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            token,
            target: VenusArbitrum.A_TOKENS[k],
        })
    }
    return params
}


export function getVenusETHDatas() {
    const tokenKeys = Object.keys(VenusETHArbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            underlying: token,
            collateralToken: VenusETHArbitrum.A_TOKENS[k],
            debtToken: constants.AddressZero,
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.VENUS_ETH
        })
    }
    return params
}

export function getVenusETHApproveDatas() {
    const tokenKeys = Object.keys(VenusETHArbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            token,
            target: VenusETHArbitrum.A_TOKENS[k],
        })
    }
    return params
}