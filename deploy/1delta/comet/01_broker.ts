import '@nomiclabs/hardhat-ethers'
import hre from 'hardhat'
import { compoundAddresses, generalAddresses, uniswapAddresses } from "../../polygon_addresses";
import { createBroker, initializeBroker } from './00_helper';

const usedMaxFeePerGas = 350_000_000_000
const usedMaxPriorityFeePerGas = 40_000_000_000


const opts = {
    // maxFeePerGas: usedMaxFeePerGas,
    // maxPriorityFeePerGas: usedMaxPriorityFeePerGas,
}

async function main() {

    const accounts = await hre.ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    console.log("Deploy Broker Proxy on", chainId, "by", operator.address)
    const broker = await createBroker(operator, opts)

    console.log('Initialize')
    await initializeBroker(operator, broker, compoundAddresses.cometUSDC[chainId], opts)

    console.log('Completed')
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

    // ---- addresses ---
    // proxy: 0x0893B8446fe77eaD760921D34d332d290FF89Ee6
    // configModule: 0xBA0623509DAC6642359357b7570616Bd3ed03Aac
    // lens: 0xa2e49883b47d33ec8E3924a60Bfb7b58477c4470
    // ownership: 0xff64a55bF958ff8710703B83e9358D90f69f0361
    // marginTrader: 0x6aB8Ab831966da6f60B236A6f4559E2DA7211ff5
    // managementModule: 0x44FA7E546C6a490C39AF2245A4A781e25E2e1Dbc
    // Initialize
    // initComet: 0xC59cf2347635D3404a7Eb11F7E17e26F24205f9a
    // completed initialization
    // Completed
    