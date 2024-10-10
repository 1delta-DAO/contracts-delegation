
import { ethers } from "hardhat";
import {
    DeltaMetaAggregator__factory,
} from "../../types";
import { getPolygonConfig } from "../polygon/utils";
import { formatEther } from "ethers/lib/utils";
import { BigNumber } from "ethers";

const FIXED_NONCE = 111111;

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    let nonce = await operator.getTransactionCount()
    console.log("operator", operator.address, "on", chainId, "with nonce", nonce)

    const gasData = await operator.getFeeData()
    console.log("gasData", gasData)

    const magwp = await new DeltaMetaAggregator__factory(operator).deploy({ ...getConfig(gasData), nonce: FIXED_NONCE })
    await magwp.deployed()
    console.log("magwp deployed")

    console.log("magwp", magwp.address)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });


function getConfig(gasData: any) {
    let returnMap: any = {}
    // if (gasData.maxFeePerGas) {
    //     returnMap['maxFeePerGas'] = addMargin(gasData.maxFeePerGas)
    //     console.log("returnMap['maxFeePerGas']", formatEther(returnMap['maxFeePerGas']))
    // }
    // if (gasData.maxPriorityFeePerGas) {
    //     returnMap['maxPriorityFeePerGas'] = addMargin(gasData.maxPriorityFeePerGas)
    //     console.log("returnMap['maxPriorityFeePerGas']", formatEther(returnMap['maxPriorityFeePerGas']))
    // }
    if (gasData.gasPrice) {
        returnMap['gasPrice'] = addMargin(gasData.gasPrice)
    }
    console.log("returnMap['gasPrice']", formatEther(returnMap['gasPrice']))
    return returnMap
}


function addMargin(am: BigNumber) {
    return am.mul(110).div(100)
}