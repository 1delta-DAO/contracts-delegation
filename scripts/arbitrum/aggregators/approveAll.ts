import { TargetParamsStruct } from "../../../types/ManagementModule"

const aggregatorsTargets = [
    '0xa669e7A0d4b3e4Fa48af2dE86BD4CD7126Be4e13', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
    '0x6A000F20005980200259B80c5102003040001068', // PARASWAP (v6.2)
    '0x1111111254eeb25477b68fb85ed929f73a960582', // 1INCH (v5)
]


export function getInsertAggregators() {
    let params: TargetParamsStruct[] = []
    aggregatorsTargets.map(target => {
        params.push({
            target,
            value: true
        })
    })
    return params
}