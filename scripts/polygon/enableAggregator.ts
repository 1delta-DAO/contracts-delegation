
import { ethers } from "hardhat";
import {
    PolygonManagementModule__factory,
} from "../../types";
import { getPolygonConfig } from "./utils";
import { ONE_DELTA_GEN2_ADDRESSES_POLYGON } from "./addresses/oneDeltaAddresses";

const aggregatorsTargets = [
    '0x6a000f20005980200259b80c5102003040001068', // Paraswap
]

const aggregatorsToApproves = [
    '0x6a000f20005980200259b80c5102003040001068', // Paraswap
]

async function main() {
    const accounts = await ethers.getSigners()
    const operator = accounts[1]
    const chainId = await operator.getChainId();
    if (chainId !== 137) throw new Error("invalid chainId")
    console.log("operator", operator.address, "on", chainId)

    // we manually increment the nonce
    let nonce = await operator.getTransactionCount()

    const oneDeltaManagement = await new PolygonManagementModule__factory(operator).attach(ONE_DELTA_GEN2_ADDRESSES_POLYGON.proxy)

    // add aggregators
    const tx = await oneDeltaManagement.setValidTarget(aggregatorsToApproves[0], aggregatorsTargets[0], true, getPolygonConfig(nonce++))
    await tx.wait()

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
