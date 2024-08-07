// hardhat.config.ts

import 'dotenv/config';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-solhint';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-abi-exporter';
import 'hardhat-deploy';
import 'hardhat-deploy-ethers';
import 'hardhat-gas-reporter';
import 'hardhat-spdx-license-identifier';
import '@typechain/hardhat';
import 'hardhat-watcher';
import 'solidity-coverage';
import "hardhat-contract-sizer";
// import '@openzeppelin/hardhat-upgrades';
// import {accounts} from './utils/networks';

//import './tasks';
import * as dotenv from 'dotenv';

dotenv.config();

import { HardhatUserConfig } from 'hardhat/types';
import { removeConsoleLog } from 'hardhat-preprocessor';



const LOW_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1_500,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const HIGHEST_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 1_000_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const DEFAULT_COMPILER_SETTINGS = {
  version: '0.8.17',
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}


const IZI_COMPILER_SETTINGS = {
  version: "0.8.4",
  settings: {
    optimizer: {
      enabled: true,
      runs: 100
    },
    outputSelection: {
      "*": {
        "*": [
          "abi",
          "evm.bytecode",
          "evm.deployedBytecode",
          "evm.methodIdentifiers",
          "metadata"
        ],
      }
    }
  }
}

const LOWEST_OPTIMIZER_COMPILER_SETTINGS = {
  version: '0.8.17',
  settings: {
    viaIR: true,
    optimizer: {
      enabled: true,
      runs: 1_000,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const accounts = {
  mnemonic:
    'test test test test test test test test test test test junk',
  accountsBalance: "990000000000000000000",
};

const pk1: string = process.env.PK_1 || '';
const pk2: string = process.env.PK_2 || '';
const pk3: string = process.env.PK_3 || '';
const pk4: string = process.env.PK_3 || '';
const pk5: string = process.env.PK_5 || '';

// fetch wallet addresses from env
const address1: string = process.env.ADDRESS_1 || '';
const address2: string = process.env.ADDRESS_2 || '';
const address3: string = process.env.ADDRESS_3 || '';
const address4: string = process.env.ADDRESS_3 || '';
const address5: string = process.env.ADDRESS_5 || '';

const config: HardhatUserConfig = {
  abiExporter: {
    path: './abi',
    clear: false,
    flat: true,
    // only: [],
    // except: []
  },
  defaultNetwork: 'hardhat',
  etherscan: {
    customChains: [
      {
        network: "mantle",
        chainId: 5000,
        urls: {
          apiURL: "https://explorer.mantle.xyz/api",
          browserURL: "https://explorer.mantle.xyz/"
        }
      }
    ],
    apiKey: {
      mantle: 'abc',
      mainnet: process.env.ETHERSCAN_API_KEY ?? '',
      polygon: process.env.POLYGONSCAN_API_KEY ?? ''
    }
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: 'USD',
    enabled: true,
    excludeContracts: ['contracts/mocks/', 'contracts/libraries/'],
  },
  mocha: {
    timeout: 500000,
  },
  namedAccounts: {
    operator: address1,
    deployer: {
      default: address2,
      localhost: address3,
      ropsten: address2,
      'bsc-testnet': address2,
      kovan: address2,
      mumbai: address2,
      fuji: address2,
      goerli: address2,
      matic: address5
    },
    localhost: {
      default: address3,
    },
    user: {
      default: address4,
    },
    dev: {
      default: address2,
      localhost: address3,
    },
  },
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      gasPrice: 120 * 1000000000,
      chainId: 1,
    },
    localhost: {
      url: 'http://localhost:8545',
      live: false,
      saveDeployments: true,
      tags: ['local'],
      accounts
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
        blockNumber: 62219594,
        url: `https://rpc.ankr.com/mantle`,
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
      saveDeployments: true,
      tags: ['staging'],
      gasPrice: 5000000000,
      gasMultiplier: 2,
    },
    goerli: {
      url: 'https://rpc.ankr.com/eth_goerli',
      // url: "https://goerli.blockpi.network/v1/rpc/public", //
      // url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [pk2],
      chainId: 5,
      // live: true,
      // saveDeployments: true,
      // tags: ['staging'],
      // gasPrice: 5000000000,
      // gasMultiplier: 2,
    },
    moonbase: {
      url: 'https://rpc.testnet.moonbeam.network',
      accounts,
      chainId: 1287,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gas: 5198000,
      gasMultiplier: 2,
    },
    fantom: {
      url: 'https://rpcapi.fantom.network',
      accounts,
      chainId: 250,
      live: true,
      saveDeployments: true,
      gasPrice: 22000000000,
    },
    'fantom-testnet': {
      url: 'https://rpc.testnet.fantom.network',
      accounts,
      chainId: 4002,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    matic: {
      // url: 'https://matic-mainnet.chainstacklabs.com',
      // url: 'https://rpc-mainnet.maticvigil.com',
      url: 'https://rpc.ankr.com/polygon',
      // url:  `https://polygon-mainnet.public.blastapi.io`,
      accounts: [pk5, pk1],
      chainId: 137,
    },
    mantle: {
      url: 'https://rpc.mantle.xyz',
      accounts: [pk5, pk1],
      chainId: 5000,
    },
    mumbai: {
      url: 'https://rpc-mumbai.maticvigil.com/',
      accounts: [pk3, pk2],
      chainId: 80001,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    xdai: {
      url: 'https://rpc.xdaichain.com',
      accounts,
      chainId: 100,
      live: true,
      saveDeployments: true,
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org',
      accounts,
      chainId: 56,
      live: true,
      saveDeployments: true,
    },
    'bsc-testnet': {
      url: 'https://data-seed-prebsc-2-s3.binance.org:8545',
      //accounts,
      chainId: 97,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 1,
      accounts: [pk1, pk2],
      gas: 2100000,
      gasPrice: 10000000000,
      // blockGasLimit: 900000000,
    },
    heco: {
      url: 'https://http-mainnet.hecochain.com',
      accounts,
      chainId: 128,
      live: true,
      saveDeployments: true,
    },
    'heco-testnet': {
      url: 'https://http-testnet.hecochain.com',
      accounts,
      chainId: 256,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    avalanche: {
      url: 'https://api.avax.network/ext/bc/C/rpc',
      accounts,
      chainId: 43114,
      live: true,
      saveDeployments: true,
      gasPrice: 470000000000,
    },
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      accounts: [pk1, pk2],
      chainId: 43113,
      live: true,
      saveDeployments: true,
      // tags: ['staging'],
      // gasMultiplier: 4,
      // gas: 800000000,
      // gasPrice: 25000000000,
    },
    harmony: {
      url: 'https://api.s0.t.hmny.io',
      accounts,
      chainId: 1666600000,
      live: true,
      saveDeployments: true,
    },
    'harmony-testnet': {
      url: 'https://api.s0.b.hmny.io',
      accounts,
      chainId: 1666700000,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    okex: {
      url: 'https://exchainrpc.okex.org',
      accounts,
      chainId: 66,
      live: true,
      saveDeployments: true,
    },
    'okex-testnet': {
      url: 'https://exchaintestrpc.okex.org',
      accounts,
      chainId: 65,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    arbitrum: {
      url: 'https://arb1.arbitrum.io/rpc',
      accounts,
      chainId: 42161,
      live: true,
      saveDeployments: true,
      blockGasLimit: 700000,
    },
    'arbitrum-testnet': {
      url: 'https://kovan3.arbitrum.io/rpc',
      accounts,
      chainId: 79377087078960,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
    celo: {
      url: 'https://forno.celo.org',
      accounts,
      chainId: 42220,
      live: true,
      saveDeployments: true,
    },
    palm: {
      url: 'https://palm-mainnet.infura.io/v3/da5fbfafcca14b109e2665290681e267',
      accounts,
      chainId: 11297108109,
      live: true,
      saveDeployments: true,
    },
    'palm-testnet': {
      url: 'https://palm-testnet.infura.io/v3/da5fbfafcca14b109e2665290681e267',
      accounts,
      chainId: 11297108099,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
      gasMultiplier: 2,
    },
  },
  paths: {
    artifacts: 'artifacts',
    cache: 'cache',
    deploy: 'deploy',
    deployments: 'deployments',
    imports: 'imports',
    sources: 'contracts',
    tests: 'test/1delta',
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (bre) =>
        bre.network.name !== 'hardhat' && bre.network.name !== 'localhost'
    ),
  },
  solidity: {
    compilers: [
      // venus
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
      // compound
      {
        version: '0.8.15',
        settings: {
          optimizer: (
            process.env['OPTIMIZER_DISABLED'] ? { enabled: false } : {
              enabled: true,
              runs: 1,
              details: {
                yulDetails: {
                  optimizerSteps: 'dhfoDgvulfnTUtnIf [xa[r]scLM cCTUtTOntnfDIul Lcul Vcul [j] Tpeul xa[rul] xa[r]cL gvif CTUca[r]LsTOtfDnca[r]Iulc] jmul[jul] VcTOcul jmul'
                },
              },
            }
          ),
          outputSelection: {
            "*": {
              "*": ["evm.deployedBytecode.sourceMap"]
            },
          },
          viaIR: process.env['OPTIMIZER_DISABLED'] ? false : true,
        },
      },
      {
        version: '0.6.12',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000_000,
          },
        },
      },
      // 1delta
      {
        version: '0.8.26',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000_000,
          },
          evmVersion: 'paris',
        },
      },
      // algebra
      {
        version: '0.8.17',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000_000,
          },
          evmVersion: 'london',
        },
      },
      // uniswap
      {
        version: '0.7.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 800,
          },
          metadata: {
            // do not include the metadata hash, since this is machine dependent
            // and we want all generated code to be deterministic
            // https://docs.soliditylang.org/en/v0.7.6/metadata.html
            bytecodeHash: 'none',
          },
        },
      },
      // iZi
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100
          },
          outputSelection: {
            "*": {
              "*": [
                "abi",
                "evm.bytecode",
                "evm.deployedBytecode",
                "evm.methodIdentifiers",
                "metadata"
              ],
            }
          }
        }
      },

      // aave
      {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10_0000,
          },
          evmVersion: 'london',
        },
      },
      // Uniswap V2
      {
        version: '0.6.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
          evmVersion: 'istanbul',
        },
      },
      {
        version: '0.5.16',
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
          evmVersion: 'istanbul',
        },
      }
    ],
    overrides: {
      "contracts/external-protocols/aave-v3-core/protocol/pool/Pool.sol": {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          evmVersion: 'london',
        },
      },
      "contracts/external-protocols/aave-v3-core/protocol/libraries/logic/BorrowLogic.sol": {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          evmVersion: 'london',
        },
      },
      "contracts/external-protocols/aave-v3-core/protocol/pool/PoolConfigurator.sol": {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          evmVersion: 'london',
        },
      },
      "contracts/external-protocols/uniswapV3/periphery/MinimalSwapRouter.sol": {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1_000_000,
          },
          metadata: {
            bytecodeHash: 'none',
          },
        },
      },
      // venus
      "contracts/external-protocols/venus/test/ComptrollerHarness.sol": {
        version: "0.5.16",
        settings: {
          evmVersion: 'istanbul',
          optimizer: {
            enabled: true,
            runs: 0,
          },
        },
      },
      "contracts/external-protocols/venus/test/VenusBep20Harness.sol": {
        version: "0.5.16",
        settings: {
          evmVersion: 'istanbul',
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      // izi
      "contracts/external-protocols/iZi/core/iZiSwapFactory.sol": IZI_COMPILER_SETTINGS,
      "contracts/external-protocols/iZi/periphery/LiquidityManager.sol": IZI_COMPILER_SETTINGS,
      // algebra settings
      "contracts/external-protocols/algebra/core/base/AlgebraPoolBase.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/base/DerivedState.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/base/ReentrancyGuard.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/base/common/Timestamp.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/libraries/Constants.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/libraries/LimitOrderManagement.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/libraries/PriceMovementMath.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/libraries/TickManagement.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/libraries/TokenDeltaMath.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/PriceMovementMathEchidnaTest.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/PriceMovementMathTest.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/SafeMathTest.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/TestAlgebraRouter.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/TickOverflowSafetyEchidnaTest.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/TickTest.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/periphery/test/TestAlgebraCallee.sol": DEFAULT_COMPILER_SETTINGS,
      "contracts/external-protocols/algebra/core/test/TokenDeltaMathEchidnaTest.sol": DEFAULT_COMPILER_SETTINGS,
      // core
      'contracts/external-protocols/algebra/core/AlgebraFactory.sol': HIGHEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/core/DataStorageOperator.sol': HIGHEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/core/AlgebraPoolDeployer.sol': DEFAULT_COMPILER_SETTINGS,
      // periphery
      'contracts/external-protocols/algebra/periphery/NonfungiblePositionManager.sol': LOW_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/LimitOrderManager.sol': LOW_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/test/MockTimeNonfungiblePositionManager.sol': LOW_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/test/NFTDescriptorTest.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/NonfungibleTokenPositionDescriptor.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/libraries/NFTDescriptor.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
      'contracts/external-protocols/algebra/periphery/libraries/NFTSVG.sol': LOWEST_OPTIMIZER_COMPILER_SETTINGS,
    }
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
  },
  watcher: {
    compile: {
      tasks: ['compile'],
      files: ['./src'],
      verbose: true,
    },
  },
  contractSizer: {
    runOnCompile: false,
    disambiguatePaths: false,
  },
};

export default config;
