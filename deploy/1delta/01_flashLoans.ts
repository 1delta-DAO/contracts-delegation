import '@nomiclabs/hardhat-ethers'
import hre from 'hardhat'
import { balancerV2Vault } from '../../scripts/miscAddresses';
import { aaveAddresses } from "../polygon_addresses";
import { createFlashBroker } from './00_helperFlash';
import { initializeFlashBroker } from './00_initializeFlashBroker';

const usedMaxFeePerGas = 170_000_000_000
const usedMaxPriorityFeePerGas = 70_000_000_000

const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
    // gasLimit: 4_500_000
}

async function main() {

    const accounts = await hre.ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    console.log("Deploy Broker Proxy on", chainId, "by", operator.address)
    const broker = await createFlashBroker(operator, aaveAddresses.v3pool[chainId], balancerV2Vault[chainId], opts)

    console.log('Initialize')
    await initializeFlashBroker(chainId, operator, broker.proxy.address, aaveAddresses.v3pool[chainId], false, opts)

    console.log('Completed')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
// broker: 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2
// config: 0xcB6Eb8df68153cebF60E1872273Ef52075a5C297    
// lens: 0x8a5b01FD188785D0eb4578899f1aECD74b4C3071
// ownership: 0x85D682FA4115f6a1Ed91170E705A50D532e3B6BD
// brokerModuleBalancer: 0x7a59ddbB76521E8982Fa3A08598C9a83b14A6C07
// brokerModuleAave: 0xCe434378adacC51d54312c872113D687Ac19B516
// managementModule: 0x32198Ee619fAd24169fa94A149Cb5205701C6AB1
// viewerModule: 0x7e2D250E4FD0EeD6BD2cB3DC525A2b9f12508152
// initAAVE: 0x80416C1e314662D6417ba9fA4F983fE4507785ff
