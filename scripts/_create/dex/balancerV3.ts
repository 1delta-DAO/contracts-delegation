import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";

const BALANCER_V3 = {
    vault: {
        [Chain.ETHEREUM_MAINNET]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.ARBITRUM_ONE]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.AVALANCHE_C_CHAIN]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.GNOSIS]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.BASE]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.POLYGON_ZKEVM]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
        [Chain.OP_MAINNET]: '0xbA1333333333a1BA1108E8412f11850A5C319bA9',
    },
    forkId: "0"
}


interface BalancerInfo  {
    vault: {
        [chainId: string]: string
    },
    forkId: string
}


export const BALANCER_V3_FORKS: { [s: string]: BalancerInfo } = {
    [DexProtocol.BALANCER_V3]: BALANCER_V3,
}