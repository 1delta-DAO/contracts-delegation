import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { NativeOrders__factory } from "../../../../types"
import { BigNumber } from "ethers"

export const createNativeOrder = async (owner: SignerWithAddress, collector: string, feeMultiplier: BigNumber, weth = collector) => {

    const limitModule = await new NativeOrders__factory(owner).deploy(weth, collector, feeMultiplier)

    return limitModule
}