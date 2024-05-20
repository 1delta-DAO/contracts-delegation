import { ManagementModule__factory } from "../../../types";
import { TOKENS_MANTLE } from "../addresses/tokens";
import { AURELIUS_POOL } from "../addresses/aureliusAddresses";
import { LENDLE_POOL } from "../addresses/lendleAddresses";

const managementInterface = ManagementModule__factory.createInterface()

const STRATUM_USD = [
    TOKENS_MANTLE.USDC,
    TOKENS_MANTLE.USDT,
    '0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3' // mUSD
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

export function getStratumApproves(): string[] {
    return [
        managementInterface.encodeFunctionData("approveAddress", [
            Object.values(STRATUM_USD),
            stratum3USD
        ]),
        managementInterface.encodeFunctionData("approveAddress", [
            Object.values(STRATUM_USD_2),
            stratum3USD_2
        ]),
        managementInterface.encodeFunctionData("approveAddress", [
            Object.values(underlyingsEth),
            stratumETH
        ])
    ]
}

export function getLendleApproves(): string[] {
    return [
        managementInterface.encodeFunctionData("approveAddress", [
            Object.values(TOKENS_MANTLE),
            LENDLE_POOL
        ]
        )
    ]
}

export function getAureliusApproves(): string[] {
    return [
        managementInterface.encodeFunctionData("approveAddress", [
            Object.values(TOKENS_MANTLE),
            AURELIUS_POOL
        ]
        )
    ]
}

