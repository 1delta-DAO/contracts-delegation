import '@nomiclabs/hardhat-ethers'
import { ethers } from "hardhat";
import { OneDeltaQuoter__factory } from '../types'

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("Deploy Quoter on", chainId, "by", operator.address)

    const deploymentData = await new OneDeltaQuoter__factory(operator).getDeployTransaction()
    const estimatedGas = await ethers.provider.estimateGas({ data: deploymentData.data });

    console.log("EST GAS", estimatedGas.toString())

    // deploy Quoter
    const quoter = await new OneDeltaQuoter__factory(operator).deploy({ gasLimit: estimatedGas.mul(105).div(100) })
    await quoter.deployed()

    console.log('Quoter:', quoter.address)
}

// Quoter: 0x62CF92A2dBbc4436ee508f4923e6Aa8dfF2A5E0c
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });