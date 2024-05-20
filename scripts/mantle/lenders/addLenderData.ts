import { ManagementModule__factory } from "../../../types";
import { LENDLE_A_TOKENS, LENDLE_S_TOKENS, LENDLE_V_TOKENS } from "../addresses/lendleAddresses";
import { constants } from "ethers";
import { AURELIUS_A_TOKENS, AURELIUS_S_TOKENS, AURELIUS_V_TOKENS } from "../addresses/aureliusAddresses";
import { TOKENS_MANTLE } from "../addresses/tokens";


const managementInterface = ManagementModule__factory.createInterface()

export function getAddLendleTokens() {
    const tokenKeys = Object.keys(LENDLE_A_TOKENS)
    let calls: string[] = []
    for (let k of tokenKeys) {
        console.log("add lendle tokens a", k)
        const token = TOKENS_MANTLE[k]
        calls.push(
            managementInterface.encodeFunctionData("addGeneralLenderTokens", [
                token,
                LENDLE_A_TOKENS[k],
                LENDLE_V_TOKENS[k],
                LENDLE_S_TOKENS?.[k] ?? constants.AddressZero,
                0
            ]
            )
        )
    }
    return calls
}

export function getAddAureliusTokens() {
    const tokenKeys = Object.keys(AURELIUS_A_TOKENS)
    let calls: string[] = []
    for (let k of tokenKeys) {
        console.log("add lendle tokens a", k)
        const token = TOKENS_MANTLE[k]
        calls.push(
            managementInterface.encodeFunctionData("addGeneralLenderTokens", [
                token,
                AURELIUS_A_TOKENS[k],
                AURELIUS_V_TOKENS[k],
                AURELIUS_S_TOKENS?.[k] ?? constants.AddressZero,
                1
            ]
            )
        )
    }
    return calls
}