import '@nomiclabs/hardhat-ethers'
import hre from 'hardhat'
import { balancerV2Vault } from '../../scripts/miscAddresses';
import { aaveAddresses } from "../00_addresses";
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

// goerli
// configModule: 0xefC2640C978cC5B695815E4B69245943d5e6dcE4
// brokerProxy: 0x0C233b11F886da1D5206Fa9e0d48293c23A4fDb9
// ownership: 0x1ae0E121d80C93862e725BD2F4E92E59d6fbEb29
// marginTrader: 0x628Ef1FE0A45be404c451c613c0B2c901452684f
// managementModule: 0x0Be9058fE2DB31E2DaCEbbE566D227D0CbfA41C8
// viewerModule: 0x636Ea7E9C4409Be6CE24A4E14bE73ef8830D83F0
// callbackModule: 0x90Ff5Fe462d3CB10221dc9B1A767D803757d3216
// moneyMarket: 0x66107C04AfB3740fE0A3760f88C4022E4e968847

