import { MantleManagementModule } from "../../../types";
import { getPolygonConfig } from "../utils";
import { AAVE_V3_POOL, AAVE_V3_UNDERLYINGS } from "../addresses/aaveV3Addresses";
import { AAVE_V2_POOL, AAVE_V2_UNDERLYINGS } from "../addresses/aaveV2Addresses";
import { COMET_USDC, COMET_USDC_UNDERLYINGS } from "../addresses/compoundV3Addresses";
import { YLDR_POOL, YLDR_UNDERLYINGS } from "../addresses/yldrAddresses";

export async function execAaveV3Approves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(AAVE_V3_UNDERLYINGS),
        AAVE_V3_POOL,
        getPolygonConfig(nonce++)
    )
    await tx.wait()
    return nonce
}

export async function execAaveV2Approves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(AAVE_V2_UNDERLYINGS),
        AAVE_V2_POOL,
        getPolygonConfig(nonce++)
    )
    await tx.wait()
    return nonce
}

export async function execYldrApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(YLDR_UNDERLYINGS),
        YLDR_POOL,
        getPolygonConfig(nonce++)
    )
    await tx.wait()
    return nonce
}

export async function execCompoundV3USDCEApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(COMET_USDC_UNDERLYINGS),
        COMET_USDC,
        getPolygonConfig(nonce++)
    )
    await tx.wait()
    return nonce
}