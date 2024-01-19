import '@nomiclabs/hardhat-ethers'
import { ethers } from "hardhat";
import { OneDeltaQuoterMantle__factory } from '../../types'

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("Deploy Module Manager on", chainId, "by", operator.address)


    console.log("deploy quoter on mantle")

    const deploymentData = await new OneDeltaQuoterMantle__factory(operator).getDeployTransaction()
    const estimatedGas = await ethers.provider.estimateGas({ data: deploymentData.data });

    console.log("EST GAS", estimatedGas.toString())
    const quoter = await new OneDeltaQuoterMantle__factory(operator).deploy({ gasLimit: estimatedGas.mul(105).div(100) })
    await quoter.deployed()

    console.log('quoter:', quoter.address) // 0x9944327aEe1276c1E9343De9E7131877B6B2aC38
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });