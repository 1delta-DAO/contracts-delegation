import { BigNumber } from "ethers";


export const sumBn = (ns: BigNumber[]): BigNumber => {
    return ns.reduce((a, b) => a.add(b))
}


export const minBn = (ns: BigNumber[]): BigNumber => {
    return ns.sort((a, b) => a.lt(b) ? -1 : 1)[0]
}