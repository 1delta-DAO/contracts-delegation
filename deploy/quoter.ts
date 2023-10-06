import '@nomiclabs/hardhat-ethers'
import { ethers } from "hardhat";
import { OneDeltaQuoter__factory } from '../types'

async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    console.log("Deploy Quoter on", chainId, "by", operator.address)
    // deploy Quoter
    const quoter = await new OneDeltaQuoter__factory(operator).deploy()
    await quoter.deployed()

    console.log('Quoter:', quoter.address)
}

// Quoter: 0x1420E68e422F673C95Bf37aE8938C87285BA75De
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });