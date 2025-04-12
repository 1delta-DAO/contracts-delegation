import { Chain } from "@1delta/asset-registry";
import { DexProtocol } from "./dexs";
const MAVERICK_V2_DATA = {
    codeHash: { default: "0xbb7b783eb4b8ca46925c5384a6b9919df57cb83da8f76e37291f58d0dd5c439a" },

    // https://docs.mav.xyz/technical-reference/contract-addresses/v2-contract-addresses
    // For chains: mainnet, base, bnb, arbitrum, scroll, sepolia
    factories: {
        [Chain.ETHEREUM_MAINNET]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.BASE]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.BNB_SMART_CHAIN_MAINNET]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.ARBITRUM_ONE]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e",
        [Chain.SCROLL]: "0x0A7e848Aca42d879EF06507Fca0E7b33A0a63c1e"
    }
}


interface UniswapV3Info {
    factories: { [chain: string]: string },
    codeHash: { [chainOrDefault: string]: string },
}

export const MAVERICK_V2: { [s: string]: UniswapV3Info } = {
    [DexProtocol.MAVERICK_V2]: MAVERICK_V2_DATA,
}
