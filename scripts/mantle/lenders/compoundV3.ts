import { ApproveParamsStruct } from "../../../types/ManagementModule";
import { CompoundV3Mantle } from "../addresses/compoundV3Addresses";
import { TOKENS_MANTLE } from "../addresses/tokens";

export function getCompoundV3Approves() {
    let params: ApproveParamsStruct[] = []

    Object.values(CompoundV3Mantle.COMET_DATAS).map(cometParams => {
        cometParams.assets.map(k => {
            const token = TOKENS_MANTLE[k]
            if(!token) throw new Error("token not defined:" + k)
            params.push({
                token,
                target: cometParams.comet,
            })
        })
    })
    return params
}