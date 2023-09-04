import { ethers } from "hardhat"
import { FeeAmount } from "../../uniswap-v3/periphery/shared/constants"
import { InterestRateMode } from "./aaveFixture"

// token address, poolFee, poolId, tradeType
const typeSliceAggregator = ['address', 'uint24', 'uint8', 'uint8',]

export function encodeAggregatorPathEthers(path: string[], fees: FeeAmount[], flags: number[], pIds: number[], flag = -1): string {
  if (path.length != fees.length + 1) {
    throw new Error('path/fee lengths do not match')
  }
  let types: string[] = []
  let data: string[] = []
  for (let i = 0; i < fees.length; i++) {
    const p = path[i]
    types = [...types, ...typeSliceAggregator]
    data = [...data, p, String(fees[i]), String(pIds[i]), String(flags[i])]
  }
  // add last address and flag
  types.push('address')
  types.push('uint8')

  data.push(path[path.length - 1])

  if (flag >= 0)
    data.push(String(flag))

  // console.log(data)
  // console.log(types)

  return ethers.utils.solidityPack(types, data)
}


export enum TradeOperation {
  Open = 'Open',
  Trim = 'Trim',
  Collateral = 'Collateral',
  Debt = 'Debt'
}

export enum TradeType {
  exactIn = 'exactIn',
  exactOut = 'exactOut'
}

export const encodeTradePathMargin = (
  route: string[],
  fees: FeeAmount[],
  pIds: number[],
  tradeOperation: TradeOperation,
  tradeType: TradeType,
  modeIn: InterestRateMode,
  modeOut: InterestRateMode
) => {
  let first: number; let last: number;
  switch (tradeType) {
    case TradeType.exactIn:
      switch (tradeOperation) {
        case TradeOperation.Open: {
          first = 6;
          last = modeIn;
          break;
        }
        case TradeOperation.Trim: {
          first = 7;
          last = 3;
          break;
        }
        case TradeOperation.Debt: {
          first = modeOut + 6;
          last = modeIn;
          break;
        }
        case TradeOperation.Collateral: {
          first = 6;
          last = 3;
          break;
        }
      }
    default:
      switch (tradeOperation) {
        case TradeOperation.Open: {
          first = 3;
          last = modeIn;
          break;
        }
        case TradeOperation.Trim: {
          first = 4;
          last = modeOut + 3;
          break;
        }
        case TradeOperation.Debt: {
          first = 4;
          last = 2;
          break;
        }
        case TradeOperation.Collateral: {
          first = 3;
          last = 3;
          break;
        }
      }
  }
  if (route.length === 2) {
    return encodeAggregatorPathEthers(
      route,
      fees,
      [first], // action
      pIds, // pid
      last // flag
    )
  } else
    return encodeAggregatorPathEthers(
      route,
      fees,
      [first, ... new Array(fees.length - 1).fill(tradeType === TradeType.exactIn ? 0 : 1)], // action
      pIds, // pid
      last // flag
    )
}