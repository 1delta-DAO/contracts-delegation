import '@nomiclabs/hardhat-ethers'
import { ethers } from "hardhat";
import { OneDeltaQuoterMantle__factory } from '../../types'

const MANTLE_CONFIGS = {
    maxFeePerGas: 0.02 * 1e9,
    maxPriorityFeePerGas: 0.02 * 1e9
}

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("Deploy Module Manager on", chainId, "by", operator.address)


    console.log("deploy quoter on mantle")

    const deploymentData = await new OneDeltaQuoterMantle__factory(operator).getDeployTransaction()
    const estimatedGas = await ethers.provider.estimateGas({ data: deploymentData.data });

    console.log("EST GAS", estimatedGas.toString())
    const quoter = await new OneDeltaQuoterMantle__factory(operator).deploy({ gasLimit: estimatedGas.mul(105).div(100), ...MANTLE_CONFIGS  })
    await quoter.deployed()

    console.log('quoter:', quoter.address) // 0x9190d8E9EAC0174199AFa0f6189F2bF15989C7B8
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });