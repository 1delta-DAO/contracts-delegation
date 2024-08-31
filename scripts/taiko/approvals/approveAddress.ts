import { MantleManagementModule } from "../../../types";
import { TOKENS_TAIKO } from "../addresses/tokens";
import { HANA_A_TOKENS, HANA_POOL } from "../addresses/hanaAddresses";
import { MERIDIAN_A_TOKENS, MERIDIAN_POOL } from "../addresses/meridianAddresses";
import { getTaikoConfig } from "../utils";


export async function execMeridianApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.keys(MERIDIAN_A_TOKENS).map(name=> TOKENS_TAIKO[name]),
        MERIDIAN_POOL,
        getTaikoConfig(nonce++)
    )
    await tx.wait()
    return nonce

}

export async function execHanaApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.keys(HANA_A_TOKENS).map(name=> TOKENS_TAIKO[name]),
        HANA_POOL,
        getTaikoConfig(nonce++)
    )
    await tx.wait()
    return nonce
}
