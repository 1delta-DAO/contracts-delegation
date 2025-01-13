import { TargetParamsStruct } from "../../../types/ManagementModule"

const aggregatorsTargets = [
    '0x4E3288c9ca110bCC82bf38F09A7b425c095d92Bf', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
    '0x6A000F20005980200259B80c5102003040001068', // PARASWAP,
    '0x1111111254eeb25477b68fb85ed929f73a960582' // 1inch
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