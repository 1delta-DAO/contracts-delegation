import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { ConfigModule__factory, DeltaBrokerProxy__factory, NativeOrders__factory } from "../../../../types"
import { ModuleConfigAction, getSelectors } from "../../../libraries/diamond"
import { BigNumber } from "ethers"

export const createNativeOrder = async (owner: SignerWithAddress, collector: string, feeMultiplier: BigNumber) => {

    const config = await new ConfigModule__factory(owner).deploy()
    const proxy = await new DeltaBrokerProxy__factory(owner).deploy(owner.address, config.address)

    const limitModule = await new NativeOrders__factory(owner).deploy(proxy.address, proxy.address, collector, feeMultiplier)

    const cfg = await new ConfigModule__factory(owner).attach(proxy.address)

    await cfg.connect(owner).configureModules(
        [{
            moduleAddress: limitModule.address,
            action: ModuleConfigAction.Add,
            functionSelectors: getSelectors(limitModule)
        }],
    )

    return await new NativeOrders__factory(owner).attach(proxy.address)
}