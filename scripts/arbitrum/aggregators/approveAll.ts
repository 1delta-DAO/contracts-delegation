import { TargetParamsStruct } from "../../../types/ManagementModule"

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // PARASWAP
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // 1INCH
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