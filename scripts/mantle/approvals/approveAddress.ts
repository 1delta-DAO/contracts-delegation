import { MantleManagementModule } from "../../../types";
import { TOKENS_MANTLE } from "../addresses/tokens";
import { AURELIUS_POOL } from "../addresses/aureliusAddresses";
import { LENDLE_POOL } from "../addresses/lendleAddresses";
import { getMantleConfig } from "../utils";

const STRATUM_USD = [
    TOKENS_MANTLE.USDC,
    TOKENS_MANTLE.USDT,
    TOKENS_MANTLE.mUSD // mUSD
]

const STRATUM_USD_2 = [
    TOKENS_MANTLE.USDC,
    TOKENS_MANTLE.USDT,
    TOKENS_MANTLE.USDY
]

const underlyingsEth = [
    TOKENS_MANTLE.WETH,
    TOKENS_MANTLE.METH,
]

const stratum3USD = '0xD6F312AA90Ad4C92224436a7A4a648d69482e47e'
const stratumETH = '0xe8792eD86872FD6D8b74d0668E383454cbA15AFc'
const stratum3USD_2 = '0x54A81FaA5dd6D19240054A9faE2d2f78E3FD6D46'


export async function execStratumApproves(manager: MantleManagementModule, nonce: number) {
    let tx = await manager.approveAddress(
        Object.values(STRATUM_USD),
        stratum3USD,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    tx = await manager.approveAddress(
        Object.values(STRATUM_USD_2),
        stratum3USD_2,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    tx = await manager.approveAddress(
        Object.values(underlyingsEth),
        stratumETH,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    return nonce
}

export async function execLendleApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(TOKENS_MANTLE),
        LENDLE_POOL,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    return nonce

}

export async function execAureliusApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        Object.values(TOKENS_MANTLE),
        AURELIUS_POOL,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    return nonce
}

export async function execMUSDApproves(manager: MantleManagementModule, nonce: number) {
    const tx = await manager.approveAddress(
        [TOKENS_MANTLE.USDY],
        TOKENS_MANTLE.mUSD,
        getMantleConfig(nonce++)
    )
    await tx.wait()
    return nonce
}
