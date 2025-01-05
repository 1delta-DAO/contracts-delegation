import { constants } from "ethers"
import { AvalonArbitrum, AvalonPumpBTCArbitrum } from "../addresses/avalonAddresses"
import { TOKENS_ARBITRUM } from "../addresses/tokens"
import { ArbitrumLenderId } from "../addresses/lenderIds"
import { ApproveParamsStruct, BatchAddLenderTokensParamsStruct } from "../../../types/ManagementModule"


export function getAvalonDatas() {
    const tokenKeys = Object.keys(AvalonArbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            underlying: token,
            collateralToken: AvalonArbitrum.A_TOKENS[k],
            debtToken: AvalonArbitrum.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.AVALON
        })
    }
    return params
}

export function getAvalonApproveDatas() {
    const tokenKeys = Object.keys(AvalonArbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
             token,
            target: AvalonArbitrum.POOL,
        })
    }
    return params
}


export function getAvalonPumpBTCDatas() {
    const tokenKeys = Object.keys(AvalonPumpBTCArbitrum.A_TOKENS)
    let params: BatchAddLenderTokensParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
            underlying: token,
            collateralToken: AvalonPumpBTCArbitrum.A_TOKENS[k],
            debtToken: AvalonPumpBTCArbitrum.V_TOKENS[k],
            stableDebtToken: constants.AddressZero,
            lenderId: ArbitrumLenderId.AVALON_PBTC
        })
    }
    return params
}

export function getAvalonPumpBTCApproveDatas() {
    const tokenKeys = Object.keys(AvalonPumpBTCArbitrum.A_TOKENS)
    let params: ApproveParamsStruct[] = []
    for (let k of tokenKeys) {
        const token = TOKENS_ARBITRUM[k]
        params.push({
             token,
            target: AvalonPumpBTCArbitrum.POOL,
        })
    }
    return params
}