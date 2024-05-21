
import { ethers } from "hardhat";
import { ONE_DELTA_ADDRESSES } from "../../deploy/mantle_addresses"
import { validateAddresses } from "../../utils/types";
import { getAddAureliusTokens, getAddLendleTokens } from "./lenders/addLenderData";
import { getAureliusApproves, getLendleApproves } from "./approvals/approveAddress";
import { DeltaBrokerProxy__factory } from "../../types";
import { MANTLE_CONFIGS } from "./utils";


async function main() {

    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();

    if (chainId !== 5000) throw new Error("Invalid chain, expected Mantle")

    const proxyAddress = ONE_DELTA_ADDRESSES.BrokerProxy[chainId]

    validateAddresses([proxyAddress])

    console.log("Operate on", chainId, "by", operator.address)

    const aureliusAdd = getAddAureliusTokens()
    const lendleAdd = getAddLendleTokens()
    const aureliusApproves = getAureliusApproves()
    const lendleApproves = getLendleApproves()

    const multicaller = await new DeltaBrokerProxy__factory(operator).attach(proxyAddress)

    await multicaller.estimateGas.multicall([
        ...aureliusAdd,
        ...lendleAdd,
        ...aureliusApproves,
        ...lendleApproves
    ])

    console.log("estimate done, execution")

    await multicaller.multicall([
        ...aureliusAdd,
        ...lendleAdd,
        ...aureliusApproves,
        ...lendleApproves
    ],
        MANTLE_CONFIGS
    )

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });