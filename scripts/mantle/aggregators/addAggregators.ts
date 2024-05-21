import { ManagementModule__factory } from "../../../types";
import { TOKENS_MANTLE } from "../addresses/tokens";

const underlyings = Object.values(TOKENS_MANTLE)

const aggregatorsTargets = [
    '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
    '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
]

const managementInterface = ManagementModule__factory.createInterface()

export function getAddAggregatorsMantle() {
    const approves = aggregatorsTargets.map((a) => {
        return managementInterface.encodeFunctionData("approveAddress", [underlyings, a])
    })

    const addAsValid = aggregatorsTargets.map((a) => {
        return managementInterface.encodeFunctionData("setValidTarget", [a, true])
    })

    return [...approves, ...addAsValid]
}

