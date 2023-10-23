
import { encodeQuoterPathEthers } from "../test/1delta/shared/aggregatorPath";
import { OneDeltaQuoter, OneDeltaQuoterMantle__factory, UniswapInterfaceMulticall__factory } from "../types";
const { ethers } = require("hardhat");


const weth = '0xdeaddeaddeaddeaddeaddeaddeaddeaddead1111'
const usdc = '0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9'
const wmt = '0x78c1b0c915c4faa5fffa6cabf0219da63d7f4cb8'
const btc = '0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2'


async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[0]
    const chainId = await operator.getChainId();
    const quoter = await new OneDeltaQuoterMantle__factory(operator).attach('0xcB6Eb8df68153cebF60E1872273Ef52075a5C297')


    const route = encodeQuoterPathEthers(
        [usdc, wmt, usdc, btc].reverse(),
        [500, 100, 0].reverse(),
        [0, 0, 50].reverse()
    )

    const routeDirect = encodeQuoterPathEthers(
        [usdc, btc].reverse(),
        [2500].reverse(),
        [0].reverse()
    )

    const amount = '1000000'
    const call = quoter.interface.encodeFunctionData('quoteExactOutput', [route, amount])
    const callDirect = quoter.interface.encodeFunctionData('quoteExactOutput', [routeDirect, amount])
    const calls = [
        call,
        callDirect
    ]
    const params = calls.slice(0, 10).map(callData => {
        return {
            target: quoter.address,
            callData,
            gasLimit: 1_500_000
        }
    })

    const multi = await new UniswapInterfaceMulticall__factory(operator).attach('0xf5bb4e61ccAC9080fb520e5F69224eE85a4D588F')
    const x = await multi.callStatic.multicall(params)
    console.log(x)

    x[1].map(d => d.success ? console.log(quoter.interface.decodeFunctionResult('quoteExactOutput', d.returnData).toString()) : null)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });