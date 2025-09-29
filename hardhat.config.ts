// hardhat.config.ts

import "dotenv/config";
import "@nomiclabs/hardhat-solhint";
import "@nomiclabs/hardhat-waffle";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-spdx-license-identifier";
import "@typechain/hardhat";
import "hardhat-watcher";
import "solidity-coverage";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-verify";
// import '@openzeppelin/hardhat-upgrades';
// import {accounts} from './utils/networks';

//import './tasks';
import * as dotenv from "dotenv";

dotenv.config();

import {HardhatUserConfig} from "hardhat/types";
import {removeConsoleLog} from "hardhat-preprocessor";

const pk1: string = process.env.PK_1 || "";
const pk2: string = process.env.PK_2 || "";
const pk3: string = process.env.PK_3 || "";
const pk4: string = process.env.PK_3 || "";
const pk5: string = process.env.PK_5 || "";
const pk6: string = process.env.PK_6 || "";

const accounts = [pk1, pk5, pk3, pk6];

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    etherscan: {
        customChains: [
            {
                network: "mantle",
                chainId: 5000,
                urls: {
                    apiURL: "https://api.mantlescan.xyz/api",
                    browserURL: "https://mantlescan.xyz/",
                },
            },
            {
                network: "taiko",
                chainId: 167000,
                urls: {
                    apiURL: "https://api.taikoscan.io/api",
                    browserURL: "https://taikoscan.io",
                },
            },
            {
                network: "hemi",
                chainId: 43111,
                urls: {
                    apiURL: "https://explorer.hemi.xyz/api",
                    browserURL: "https://explorer.hemi.xyz/",
                },
            },
            {
                network: "core",
                chainId: 1116,
                urls: {
                    apiURL: "https://openapi.coredao.org/api",
                    browserURL: "https://scan.coredao.org",
                },
            },
            {
                network: "blast",
                chainId: 81457,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/mainnet/evm/81457/etherscan",
                    browserURL: "https://blastexplorer.io",
                },
            },
            {
                network: "linea",
                chainId: 59144,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/mainnet/evm/59144/etherscan",
                    browserURL: "https://blastexplorer.io",
                },
            },
            {
                network: "metis",
                chainId: 1088,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/mainnet/evm/1088/etherscan",
                    browserURL: "https://andromeda-explorer.metis.io",
                },
            },
            {
                network: "base",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org",
                },
            },
            {
                network: "sonic",
                chainId: 146,
                urls: {
                    apiURL: "https://api.etherscan.io/v2/api?chainid=146",
                    browserURL: "https://sonicscan.org",
                },
            },
            {
                network: "fantom",
                chainId: 250,
                urls: {
                    apiURL: "https://api.ftmscan.org/api",
                    browserURL: "https://ftmscan.org",
                },
            },
            {
                network: "scroll",
                chainId: 534352,
                urls: {
                    apiURL: "https://api.scrollscan.com/api",
                    browserURL: "https://scrollscan.com",
                },
            },
            {
                network: "katana",
                chainId: 747474,
                urls: {
                    apiURL: "https://api.etherscan.io/v2/api?chainid=747474",
                    browserURL: "https://katanascan.com/",
                },
            },

            {
                network: "manta",
                chainId: 169,
                urls: {
                    apiURL: "https://api.socialscan.io/manta-pacific/v1/explorer/command_api/contract",
                    browserURL: "https://manta.socialscan.io//",
                },
            },
            {
                network: "xdc",
                chainId: 50,
                urls: {
                    browserURL: "https://xdcscan.com/",
                    apiURL: "https://api.etherscan.io/v2/api?chainid=50",
                },
            },
            {
                network: "soneium",
                chainId: 1868,
                urls: {
                    apiURL: "https://soneium.blockscout.com/api",
                    browserURL: "https://soneium.blockscout.com/",
                },
            },
            {
                network: "hyperevm",
                chainId: 999,
                urls: {
                    browserURL: "https://xdcscan.com/",
                    apiURL: "https://api.etherscan.io/v2/api?chainid=999",
                },
            },
            {
                network: "cronos",
                chainId: 25,
                urls: {
                    browserURL: "https://xdcscan.com/",
                    apiURL: "https://api.etherscan.io/v2/api?chainid=25",
                },
            },
            {
                network: "bnb",
                chainId: 56,
                urls: {
                    browserURL: "https://xdcscan.com/",
                    apiURL: "https://api.etherscan.io/v2/api?chainid=56",
                },
            },
            {
                network: "moonbeam",
                chainId: 1284,
                urls: {
                    browserURL: "https://xdcscan.com/",
                    apiURL: "https://api.etherscan.io/v2/api?chainid=1284",
                },
            },
            {
                network: "plasma",
                chainId: 9745,
                urls: {
                    apiURL: "https://api.routescan.io/v2/network/mainnet/evm/9745/etherscan",
                    browserURL: "https://plasmaexplorer.io",
                },
            },
            {
                network: "morph",
                chainId: 2818,
                urls: {
                    apiURL: "https://explorer-api.morphl2.io/api",
                    browserURL: "https://katanascan.com/",
                },
            },
        ],
        // apiKey: process.env.ETHERSCAN_API_KEY ?? "",
        apiKey: {
            mantle: process.env.MANTLESCAN_API_KEY ?? "abc",
            arbitrumOne: process.env.ARBISCAN_API_KEY ?? "",
            mainnet: process.env.ETHERSCAN_API_KEY ?? "",
            polygon: process.env.POLYGONSCAN_API_KEY ?? "",
            taiko: process.env.TAIKOSCAN_API_KEY ?? "",
            linea: process.env.ETHERSCAN_API_KEY ?? "",
            optimisticEthereum: process.env.OPSCAN_API_KEY ?? "",
            bnb: process.env.ETHERSCAN_API_KEY ?? "",
            bsc: process.env.ETHERSCAN_API_KEY ?? "",
            plasma: process.env.ETHERSCAN_API_KEY ?? "",
            gnosis: process.env.GNOSISSCAN_API_KEY ?? "",
            xdai: process.env.GNOSISSCAN_API_KEY ?? "",
            blast: process.env.BLASTSCAN_API_KEY ?? "",
            base: process.env.BASESCAN_API_KEY ?? "",
            moonbeam: process.env.ETHERSCAN_API_KEY ?? "",
            metis: "XX",
            avalanche: "XX",
            mode: "XX",
            hemi: "XX",
            berachain: "XX",
            soneium: "XX",
            xdc: process.env.ETHERSCAN_API_KEY ?? "",
            morph: "XX",
            manta: "XX",
            cronos: process.env.ETHERSCAN_API_KEY ?? "",
            katana: process.env.ETHERSCAN_API_KEY ?? "",
            hyperevm: process.env.ETHERSCAN_API_KEY ?? "",
            core: process.env.CORESCAN_API_KEY ?? "",
            sonic: process.env.ETHERSCAN_API_KEY ?? "",
            scroll: process.env.SCROLLSCAN_API_KEY ?? "",
            fantom: process.env.FANTOMSCAN_API_KEY ?? "",
        },
    },
    gasReporter: {
        coinmarketcap: process.env.COINMARKETCAP_API_KEY,
        currency: "USD",
        enabled: true,
        excludeContracts: ["contracts/mocks/", "contracts/libraries/"],
    },
    mocha: {
        timeout: 500000,
    },
    networks: {
        mainnet: {
            url: `https://eth.blockrazor.xyz`,
            accounts,
            chainId: 1,
        },
        localhost: {
            url: "http://localhost:8545",
            live: false,
            accounts,
        },
        hardhat: {
            mining: {
                // auto: false,
                // interval: 0
            },
            // allowUnlimitedContractSize: true,

            // forking: {
            //   blockNumber: 53244031,
            //   url: `https://rpc.ankr.com/polygon`,
            // },
            // forking:{
            //   blockNumber: 18748428,
            //   url: 'https://rpc.ankr.com/eth'
            // },
            forking: {
                blockNumber: 320071,
                url: `https://rpc.ankr.com/taiko`,
            },
            // forking: {
            //   blockNumber: 35180036,
            //   url: `https://rpc.ankr.com/bsc`,
            // },
        },
        rinkeby: {
            url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
            accounts,
            chainId: 4,
            live: true,
        },
        taiko: {
            url: "https://rpc.taiko.xyz",
            accounts,
            chainId: 167000,
        },
        moonbeam: {
            url: "https://rpc.api.moonbeam.network",
            accounts,
            chainId: 1284,
        },
        moonbase: {
            url: "https://rpc.testnet.moonbeam.network",
            accounts,
            chainId: 1287,
            live: true,
            gas: 5198000,
        },
        fantom: {
            url: "https://rpcapi.fantom.network",
            accounts,
            chainId: 250,
            live: true,
        },
        hemi: {
            url: "https://rpc.hemi.network/rpc",
            accounts,
            chainId: 43111,
            live: true,
        },
        soneium: {
            url: "https://rpc.soneium.org",
            accounts,
            chainId: 1868,
            live: true,
        },
        hyperevm: {
            url: "https://rpc.hyperliquid.xyz/evm",
            accounts,
            chainId: 999,
            live: true,
        },
        core: {
            url: "https://rpc.coredao.org",
            accounts,
            chainId: 1116,
            live: true,
        },
        scroll: {
            url: "https://rpc.scroll.io",
            accounts,
            chainId: 534352,
            live: true,
        },
        sonic: {
            url: "https://rpc.soniclabs.com",
            accounts,
            chainId: 146,
            live: true,
        },
        polygon: {
            url: "https://api.zan.top/polygon-mainnet",
            accounts,
            chainId: 137,
        },
        pulse: {
            url: "https://rpc.pulsechain.com",
            accounts,
            chainId: 369,
        },
        base: {
            url: "https://mainnet.base.org",
            accounts,
            live: true,
        },
        mantle: {
            url: "https://1rpc.io/mantle",
            accounts,
            chainId: 5000,
        },
        kaia: {
            url: "https://kaia.blockpi.network/v1/rpc/public",
            accounts,
            chainId: 8217,
        },
        gnosis: {
            url: "https://rpc.gnosischain.com",
            accounts,
            chainId: 100,
            live: true,
        },
        bnb: {
            url: "https://bsc-dataseed.binance.org",
            chainId: 56,
            live: true,
            accounts,
        },
        heco: {
            url: "https://http-mainnet.hecochain.com",
            accounts,
            chainId: 128,
            live: true,
        },
        mode: {
            url: "https://mainnet.mode.network",
            accounts,
            chainId: 34443,
            live: true,
        },
        avalanche: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            accounts,
            chainId: 43114,
            live: true,
        },
        unichain: {
            url: "https://mainnet.unichain.org",
            accounts,
            chainId: 130,
            live: true,
        },
        harmony: {
            url: "https://api.s0.t.hmny.io",
            accounts,
            chainId: 1666600000,
            live: true,
        },
        katana: {
            url: "https://rpc.katana.network",
            accounts,
            chainId: 747474,
            live: true,
        },
        okex: {
            url: "https://exchainrpc.okex.org",
            accounts,
            chainId: 66,
            live: true,
        },
        arbitrum: {
            url: "https://arb1.arbitrum.io/rpc",
            chainId: 42161,
            live: true,
            blockGasLimit: 700000,
            accounts,
        },
        blast: {
            url: "https://rpc.blast.io",
            live: true,
            accounts,
        },
        xdc: {
            url: "https://rpc.xdc.org",
            accounts,
            chainId: 50,
            live: true,
        },
        cronos: {
            url: "https://rpc.vvs.finance",
            accounts,
            chainId: 25,
            live: true,
        },
        berachain: {
            url: "https://rpc.berachain.com",
            accounts,
            chainId: 80094,
            live: true,
        },
        celo: {
            url: "https://forno.celo.org",
            accounts,
            chainId: 42220,
            live: true,
        },
        telos: {
            url: "https://1rpc.io/telos/evm",
            accounts,
            chainId: 40,
            live: true,
        },
        manta: {
            url: "https://pacific-rpc.manta.network/http",
            accounts,
            chainId: 169,
            live: true,
        },
        morph: {
            url: "https://rpc.morphl2.io",
            accounts,
            chainId: 2818,
            live: true,
        },
        plasma: {
            url: "https://rpc.plasma.to",
            accounts,
            chainId: 9745,
            live: true,
        },
        metis: {
            url: "https://andromeda.metis.io/?owner=1088",
            accounts,
            chainId: 1088,
            live: true,
        },
        palm: {
            url: "https://palm-mainnet.infura.io/v3/da5fbfafcca14b109e2665290681e267",
            accounts,
            chainId: 11297108109,
            live: true,
        },
        optimism: {
            url: "https://mainnet.optimism.io",
            live: true,
            accounts,
        },
        linea: {
            url: "https://1rpc.io/linea",
            live: true,
            accounts,
        },
    },
    paths: {
        artifacts: "artifacts",
        cache: "cache",
        deploy: "deploy",
        deployments: "deployments",
        imports: "imports",
        sources: "contracts",
        tests: "test/1delta",
    },
    sourcify: {
        // Disabled by default
        // Doesn't need an API key
        enabled: true,
    },
    preprocess: {
        eachLine: removeConsoleLog((bre) => bre.network.name !== "hardhat" && bre.network.name !== "localhost"),
    },
    solidity: {
        compilers: [
            // 1delta
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "cancun",
                },
            },
            // uniswap
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                },
            },
            {
                version: "0.7.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 800,
                    },
                    metadata: {
                        // do not include the metadata hash, since this is machine dependent
                        // and we want all generated code to be deterministic
                        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
                        bytecodeHash: "none",
                    },
                },
            },
            // iZi
            {
                version: "0.8.4",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100,
                    },
                    outputSelection: {
                        "*": {
                            "*": ["abi", "evm.bytecode", "evm.deployedBytecode", "evm.methodIdentifiers", "metadata"],
                        },
                    },
                },
            },

            // aave
            {
                version: "0.8.10",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_0000,
                    },
                    evmVersion: "london",
                },
            },
            // Uniswap V2
            {
                version: "0.6.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999999,
                    },
                    evmVersion: "istanbul",
                },
            },
            {
                version: "0.5.16",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 999999,
                    },
                    evmVersion: "istanbul",
                },
            },
        ],
        overrides: {
            // deploy factory
            "contracts/1delta/contracts/1delta/shared/DeployFactory.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            // ma
            "contracts/1delta/contracts/1delta/shared/MetaAggregator.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            // forwarder
            "contracts/1delta/composer/generic/CallForwarder.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            "contracts/external-protocols/misc/FeeOnTransferDetector.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            // proxy
            "contracts/external-protocols/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            "contracts/external-protocols/openzeppelin/proxy/transparent/ProxyAdmin.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            // composers
            "contracts/1delta/composer/chains/arbitrum-one/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_500,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/ethereum/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_500,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/hemi/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/katana/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "shanghai",
                },
            },
            "contracts/1delta/composer/chains/blast/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/sonic/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 5000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/polygon/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_500,
                    },
                    evmVersion: "cancun",
                },
            },
            // "contracts/1delta/composer/chains/manta/Composer.sol": {
            //     version: "0.8.28",
            //     settings: {
            //         optimizer: {
            //             enabled: true,
            //             runs: 1_500,
            //         },
            //         evmVersion: "cancun",
            //     },
            // },
            "contracts/1delta/composer/chains/telos-evm/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 25_000,
                    },
                    evmVersion: "cancun",
                },
            },
            // "contracts/1delta/composer/chains/morph/Composer.sol": {
            //     version: "0.8.28",
            //     settings: {
            //         optimizer: {
            //             enabled: true,
            //             runs: 1_500,
            //         },
            //         evmVersion: "cancun",
            //     },
            // },
            "contracts/1delta/composer/chains/metis-andromeda/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/gnosis/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/scroll/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 5_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/linea/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000,
                    },
                    evmVersion: "london",
                },
            },
            "contracts/1delta/composer/chains/fantom-opera/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "london",
                },
            },
            "contracts/1delta/composer/chains/avalanche/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 5_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/hyperevm/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 50_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/kaia/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "shanghai",
                },
            },
            "contracts/1delta/composer/chains/soneium/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 25_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/celo/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/bnb/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/mantle/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 2_000,
                    },
                    evmVersion: "shanghai",
                },
            },
            "contracts/1delta/composer/chains/core/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 25_000,
                    },
                    evmVersion: "shanghai",
                },
            },
            "contracts/1delta/composer/chains/mode/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 5_000,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/external-protocols/misc/UniswapMulticall.sol": {
                version: "0.7.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 10_000_000,
                    },
                    evmVersion: "istanbul",
                },
            },
            "contracts/1delta/composer/chains/base/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_500,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/op/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 2_500,
                    },
                    evmVersion: "cancun",
                },
            },
            "contracts/1delta/composer/chains/taiko/Composer.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 5_000,
                    },
                    evmVersion: "shanghai",
                },
            },
            "contracts/1delta/quoter/MoeJoeLens.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
            "contracts/external-protocols/misc/CometLens.sol": {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1_000_000,
                    },
                    evmVersion: "paris",
                },
            },
        },
    },
    spdxLicenseIdentifier: {
        overwrite: false,
        runOnCompile: true,
    },
    typechain: {
        outDir: "types",
        target: "ethers-v5",
    },
    watcher: {
        compile: {
            tasks: ["compile"],
            files: ["./src"],
            verbose: true,
        },
    },
    contractSizer: {
        runOnCompile: false,
        disambiguatePaths: false,
    },
};

export default config;
