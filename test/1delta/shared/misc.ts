import { BigNumber } from "ethers";
import { formatEther } from "ethers/lib/utils";

export const ONE_18 = BigNumber.from(10).pow(18)

export const toNumber = (n: BigNumber | string) => {
    return Number(formatEther(n))
}


export function expandToDecimals(n: number, d = 18): BigNumber {
    return BigNumber.from(n).mul(BigNumber.from(10).pow(d))
}
