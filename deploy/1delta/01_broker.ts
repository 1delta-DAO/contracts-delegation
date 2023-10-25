import '@nomiclabs/hardhat-ethers'
import hre from 'hardhat'
import { balancerV2Vault } from '../../scripts/miscAddresses';
import { aaveAddresses } from "../polygon_addresses";
import { createBrokerV2, initializeBroker } from './00_helper';

async function main() {

    const accounts = await hre.ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    console.log("Deploy Broker Proxy on", chainId, "by", operator.address)
    console.log("params", balancerV2Vault[chainId], aaveAddresses.v3pool[chainId])
    const broker = await createBrokerV2(operator, balancerV2Vault[chainId], aaveAddresses.v3pool[chainId])

    console.log('Initialize')
    await initializeBroker(operator, broker, aaveAddresses.v3pool[chainId])

    console.log('Completed')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// configModule: 0x32B31A066c8dd3F7b77283Ba1d89Ddaf6DA0a8aE
// brokerProxy: 0x74E95F3Ec71372756a01eB9317864e3fdde1AC53
// lens: 0x236Edc81A4e162917dA74609Eff56358E9C6aF5f
// ownership: 0xC7895BF5d8e4d049e9146ADcb750a55cD0156877
// marginTrader: 0xDFbc4D2E5EA06B5D54cf55369f1F0b8ef5FA9111
// managementModule: 0x892e4a7d578Be979E5329655949fC56781eEFdb0
// viewerModule: 0xB2B6Bd4C88124D73dE0ea128c86267AB64Fd1069
// brokerModuleAave: 0x476a0D24790a88185c721eE728d18465c66e9611
// brokerModuleBalancer: 0x5494b574bEe7aa091799ECbf3DDBFEeF5da4F720
// initAAVE: 0x2e9C883702B53c7ae3E31943D9DE4e49e43DAe71
