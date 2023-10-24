import '@nomiclabs/hardhat-ethers'
import hre from 'hardhat'
import { createBrokerV2Mantle, initializeLendleBroker } from './00_helper';
import { lendlePool } from '../../mantle_addresses';

async function main() {

    const accounts = await hre.ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 5000) throw new Error("Can only deploy on Mantle")
    console.log("Deploy Broker Proxy on", chainId, "by", operator.address)
    const broker = await createBrokerV2Mantle(operator)

    console.log('Initialize')
    await initializeLendleBroker(operator, broker, lendlePool)

    console.log('Completed')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// --- All contracts ---
// proxy: 0x4b5458BB47dCBC1a41B31b41e1a8773dE312BE9d
// configModule: 0xCe434378adacC51d54312c872113D687Ac19B516
// lens: 0x91549bad7A081742dEC72E2CF55a2477A880a798
// ownership: 0x32198Ee619fAd24169fa94A149Cb5205701C6AB1
// marginTrader: 0x7a59ddbB76521E8982Fa3A08598C9a83b14A6C07
// managementModule: 0x6Bc6aCB905c1216B0119C87Bf9E178ce298310FA
// initializer: 0xA453ba397c61B0c292EA3959A858821145B2707F

