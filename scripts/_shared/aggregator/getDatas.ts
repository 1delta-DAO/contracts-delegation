import { Chain } from "@1delta/asset-registry";

const AGGREGATORS: { [c: number]: string[] } = {
    [Chain.ARBITRUM_ONE]: [
        '0xa669e7A0d4b3e4Fa48af2dE86BD4CD7126Be4e13', // ODOS
        '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
        '0x6A000F20005980200259B80c5102003040001068', // PARASWAP (v6.2)
        '0x1111111254eeb25477b68fb85ed929f73a960582', // 1INCH (v5)
    ],
    [Chain.OP_MAINNET]: [
        '0xCa423977156BB05b13A2BA3b76Bc5419E2fE9680', // ODOS
        '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
        '0x6A000F20005980200259B80c5102003040001068', // PARASWAP (v6.2)
        '0x1111111254eeb25477b68fb85ed929f73a960582', // 1INCH (v5)
    ],
    [Chain.BASE]: [
        '0x19ceead7105607cd444f5ad10dd51356436095a1', // ODOS
        '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
        '0x6A000F20005980200259B80c5102003040001068', // PARASWAP (v6.2)
        '0x1111111254eeb25477b68fb85ed929f73a960582', // 1INCH (v5)
    ],
    [Chain.BNB_SMART_CHAIN_MAINNET]: [
        '0x0D4aB12E62D17f037D43F018Da18FF623e1AF3B2', // ODOS
        '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5', // KYBER
        '0x6A000F20005980200259B80c5102003040001068', // PARASWAP (v6.2)
        '0x1111111254eeb25477b68fb85ed929f73a960582', // 1INCH (v5)
    ],
    [Chain.MANTLE]: [
        '0xD9F4e85489aDCD0bAF0Cd63b4231c6af58c26745', // ODOS
        '0x6131B5fae19EA4f9D964eAc0408E4408b66337b5' // KYBER
    ],
    [Chain.HEMI_NETWORK]: [
        // none (yet)
    ],
}
export function getAggregators(chainId: number) {
    const a = AGGREGATORS[chainId]
    if (!a) throw new Error(`No Aggregator on ${chainId}`)
    return a.map(target => ({
        target,
        value: true
    }))
}
