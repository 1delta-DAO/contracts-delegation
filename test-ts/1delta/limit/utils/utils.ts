import { BigNumber } from "ethers";
import { NativeOrders__factory } from "../../../../types";
import { expect } from "chai";


export const sumBn = (ns: BigNumber[]): BigNumber => {
    return ns.reduce((a, b) => a.add(b))
}


export const minBn = (ns: BigNumber[]): BigNumber => {
    return ns.sort((a, b) => a.lt(b) ? -1 : 1)[0]
}

const ordersInterface = NativeOrders__factory.createInterface()

interface TxLog {
    transactionIndex: number,
    blockNumber: number,
    transactionHash: string,
    address: string,
    topics: string[],
    data: string,
    logIndex: number,
    blockHash: string

}

export const verifyLogs = (logs: TxLog[], expected: Object[], id: string) => {
    for (const log of logs) {
        const { data } = log
        let decoded: any
        try {
            decoded = ordersInterface.decodeEventLog(id, data)
        } catch (e: any) {
            continue;
        }
        const keys = Object.keys(decoded).filter(x => isNaN(Number(x)))
        let included = false
        for (const ex of expected) {
            if (keys.every(
                k => (ex as any)[k] === undefined ? true : // this allws us to skip params if the expected one is undefined
                    (ex as any)[k]?.toString().toLowerCase() === decoded[k].toString().toLowerCase())
            ) included = true;
        }
        expect(included).to.equal(true, "Not found:" + JSON.stringify(decoded))
    }
}


export function infoEqals(order: any, expected: { orderHash: string, status: number, takerTokenFilledAmount: BigNumber }) {
    Object.keys(expected).map(
        key => expect(order[key].toString()).to.equal((expected as any)[key].toString(), key)
    )
}
