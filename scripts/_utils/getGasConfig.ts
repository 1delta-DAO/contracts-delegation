import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { BigNumber } from "ethers"
import { formatEther } from "ethers/lib/utils"

export const ARBITRUM_CONFIGS = {
    maxFeePerGas: 0.01 * 1e9,
    maxPriorityFeePerGas: 0.01 * 1e9
}


export function getArbitrumConfig(n?: number) {
    return {
        ...n ? { nonce: n } : {},
        ...ARBITRUM_CONFIGS
    }
}

export async function getGasConfig(operator: SignerWithAddress) {
    const gasData: any = await operator.getFeeData()

    let returnMap: any = {}
    if (gasData.maxFeePerGas) {
        returnMap['maxFeePerGas'] = addMargin(gasData.maxFeePerGas)
        console.log("returnMap['maxFeePerGas']", formatEther(returnMap['maxFeePerGas']))
    }
    if (gasData.maxPriorityFeePerGas) {
        returnMap['maxPriorityFeePerGas'] = addMargin(gasData.maxPriorityFeePerGas)
        console.log("returnMap['maxPriorityFeePerGas']", formatEther(returnMap['maxPriorityFeePerGas']))
    }
    // if (gasData.gasPrice) {
    //     returnMap['gasPrice'] = addMargin(gasData.gasPrice)
    //     console.log("returnMap['gasPrice']", formatEther(returnMap['gasPrice']))
    // }
    return {}
}

function addMargin(am: BigNumber) {
    return am.mul(110).div(100)
}