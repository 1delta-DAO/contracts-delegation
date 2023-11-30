// mumbai
//  module.exports = [
//     '0x4d6f46Ff41908A0920986aab432ab4A98E5Cbdeb', // owner
//     "0x93c0774b0e269d4191efb3bdf65645a3722001a8", // config
//   ];


// goerli
// module.exports = [
//   '0x10E38dFfFCfdBaaf590D5A9958B01C9cfcF6A63B', // owner
//   "0xefC2640C978cC5B695815E4B69245943d5e6dcE4", // config
// ];

// polygon
// module.exports = [
//   '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
//   "0x32B31A066c8dd3F7b77283Ba1d89Ddaf6DA0a8aE", // config
// ];

// inp with factory
// module.exports = [
//   '0x1F98431c8aD98523631AE4a59f267346ea31F984', // uni factory
//   '0x794a61358D6845594F94dc1DB02A252b5b4814aD', // aave pool
// ];

// flash modules
module.exports = [
  '0x794a61358D6845594F94dc1DB02A252b5b4814aD', // aave pool
  // '0xBA12222222228d8Ba445958a75a0704d566BF2C8'// balancer
];

// npx hardhat verify --network matic 0xbb4e38021a7E4f9CA0f440EFf8a5B45792777015 --contract contracts/1delta/modules/aave/AaveFlashModule.sol:AaveFlashModule --constructor-args scripts/verify.js
// npx hardhat verify --network matic 0x2552ecbc4820bbF9B48200E6353Afa51856559c3 --contract contracts/1delta/modules/aave/BalancerFlashModule.sol:BalancerFlashModule --constructor-args scripts/verify.js



// matic
// npx hardhat verify --network matic 0xf655538718435f7981098821bE19fcE98477007b --contract contracts/1delta/modules/comet/CometMarginTraderModule.sol:CometMarginTraderModule --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0xFA9f51D2521515C68B67f5638FF764b74980D7Cc --contract contracts/1delta/modules/comet/CometMoneyMarketModule.sol:CometMoneyMarketModule  --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0x18828A9E0b5274Eb8EB152d35B17fB8AF1a29325 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0xaEc49340f7914511eD6D1F8EA8F081647730C74f --contract contracts/1delta/modules/comet/CometSweeperModule.sol:CometSweeperModule --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0x42951aD7Bf54a20E43372dDF5A65BbA7813E19f3 --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule --constructor-args scripts/verify.js


// mumbai comet lens
// npx hardhat verify --network mumbai 0x934E7212656df04E3526f6481277bDA92f082053 --contract contracts/misc/CometLens.sol:CometLens

// npx hardhat verify --network matic 0xf40ae9C07B2aca2040d40BBc6fD323DBC036033c --contract contracts/1delta/modules/deploy/polygon/aave/FlashAggregator.sol:DeltaFlashAggregator 

// npx hardhat verify --network matic 0x74E95F3Ec71372756a01eB9317864e3fdde1AC53 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/verify.js

// npx hardhat verify --network matic 0x749E32805C11637ec6c1636B868D8e880f2E07D5 --contract contracts/1delta/modules/aave/ManagementModule.sol:ManagementModule

// npx hardhat verify --network matic 0x3EdAB7c8E32be3817e5c8612a6F1160a7D67A170 --contract contracts/1delta/modules/aave/MarginTradeDataViewerModule.sol:MarginTradeDataViewerModule

// npx hardhat verify --network matic 0x32B31A066c8dd3F7b77283Ba1d89Ddaf6DA0a8aE --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule

// npx hardhat verify --network matic 0x236Edc81A4e162917dA74609Eff56358E9C6aF5f --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule


// npx hardhat verify --network matic 0xB2B6Bd4C88124D73dE0ea128c86267AB64Fd1069 --contract contracts/1delta/modules/aave/MarginTradeDataViewerModule.sol:MarginTradeDataViewerModule

