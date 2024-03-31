import { BigNumber, ContractTransaction } from "ethers";
import { ErrorParser__factory, NativeOrders__factory } from "../../../../types";
import { expect } from "chai";
import { isAddress } from "ethers/lib/utils";


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

const addressPrefix = '0x000000000000000000000000'

export const verifyLogs = (logs: TxLog[], expected: Object[], id: string) => {
    for (const log of logs) {
        const { data, topics, transactionHash } = log
        let decoded: any
        try {
            decoded = ordersInterface.decodeEventLog(id, data)
        } catch (e: any) {
            continue;
        }
        let keys = Object.keys(decoded).filter(x => isNaN(Number(x)))
        let included = false
        let hasIndexedEvents = false
        let indexedsIncluded = false
        for (const ex of expected) {
            const indexeds = (ex as any).indexed as string[]
            if (indexeds && indexeds.length > 0) {
                const types = (ex as any).indexedTypes as string[]
                keys = keys.filter(k => !indexeds.includes(k))
                hasIndexedEvents = true
                if (topics.every((topic, i) => {
                    if (i == 0) return true
                    let expectedEntry = (ex as any)[indexeds[i - 1]]
                    let expectedType = types[i - 1]
                    let addressParse = expectedType === 'address' && isAddress('0x' + topic.slice(26, topic.length))
                    if (addressParse) topic = '0x' + topic.slice(26, topic.length)
                    if (expectedEntry.toLowerCase() === topic.toLowerCase()) return true
                    else return false
                })) indexedsIncluded = true
            }
            if (keys.every(
                k => (ex as any)[k] === undefined ? true : // this allws us to skip params if the expected one is undefined
                    (ex as any)[k]?.toString().toLowerCase() === decoded[k].toString().toLowerCase())
            ) included = true;
        }
        expect(included).to.equal(true, "Not found:" + JSON.stringify(decoded))
        if (hasIndexedEvents) expect(indexedsIncluded).to.equal(true, "Not found:" + JSON.stringify(decoded))
    }
}


export function infoEqals(order: any, expected: { orderHash: string, status: number, takerTokenFilledAmount: BigNumber }) {
    Object.keys(expected).map(
        key => expect(order[key].toString()).to.equal((expected as any)[key].toString(), key)
    )
}

const ErrorInterface = ErrorParser__factory.createInterface()

/**
 * Manual error parser for custom order tx errors
 * @param func parametrized tx promise expected to thrown an error
 * @param errorName error selector
 * @param expectedArgs arguments for error, the ones skipped for checks haven to be set to undefined
 */
export const validateError = async (func: Promise<ContractTransaction>, errorName: string, expectedArgs: any[] = []) => {

    let actualFunc: string = ''
    let actulArgs: any[] = []
    let reverted = false
    let correctSelector = false
    // trigger tx
    try {
        await func
    }
    // catch error
    catch (e: any) {
        reverted = true
        // try parse the error with the given selector
        try {
            actulArgs = ErrorInterface.decodeErrorResult(errorName, e.error.data) as any
            correctSelector = true
            actualFunc = errorName
        }
        // try find actual reason
        catch (e2) {
            ErrorInterface.fragments.map(f => {
                try {
                    actulArgs = ErrorInterface.decodeErrorResult(f.name, e.error.data) as any
                    actualFunc = f.name
                }
                catch (e3) {
                    // no catch ehere
                }
            })
        }
    }

    // not reverted
    if (!reverted) {
        expect(true).to.equal(false, `Expected to be reverted with ${errorName}, but not reverted`)
    }
    // wrong error 
    if (!correctSelector) {
        expect(true).to.equal(false,
            `Expected to be reverted with ${errorName}, but reverted with ${actualFunc} instead`
        )
    }
    // not a known error
    if (actualFunc === '') {
        expect(true).to.equal(false,
            `Expected to be reverted with ${errorName}, but could not identify reason`
        )
    }
    // check length of args
    expect(actulArgs.length).to.equal(expectedArgs.length, `Expected arg length of ${expectedArgs.length} but got ${actulArgs.length}`)
    // validate args
    actulArgs.map(
        (arg, i) => {
            // we allow skipping args for the check
            if (expectedArgs[i] !== undefined) {
                const expectedArg = expectedArgs[i].toString().toLowerCase()
                const actualArg = arg.toString().toLowerCase()

                expect(
                    arg.toString().toLowerCase()
                ).to.equal(
                    expectedArg,
                    `Argument ${i} deviates: Expected: ${expectedArg}, but got ${actualArg}`
                )
            }
        }
    )
}

