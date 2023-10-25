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

// module.exports = [
//   '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
//   "0xCe434378adacC51d54312c872113D687Ac19B516", // config
// ];

module.exports = [
  '0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3', // pool
];

// npx hardhat verify --network matic 0x476a0D24790a88185c721eE728d18465c66e9611 --contract contracts/1delta/modules/aave/AaveFlashModule.sol:AaveFlashModule --constructor-args scripts/verify.js
// npx hardhat verify --network matic 0x5494b574bEe7aa091799ECbf3DDBFEeF5da4F720 --contract contracts/1delta/modules/aave/BalancerFlashModule.sol:BalancerFlashModule --constructor-args scripts/verify.js

// mumbai
// npx hardhat verify --network mumbai 0xE0d077f7C0d87909A939160EDae002cC9f33168f --contract contracts/1delta/modules/aave/AAVEMarginTraderModule.sol:AAVEMarginTraderModule
// npx hardhat verify --network mumbai 0xAA71A440e4ea9Bd108e06b556A16C60c610aFdf9 --contract contracts/1delta/modules/aave/AAVEMoneyMarketModule.sol:AAVEMoneyMarketModule
// npx hardhat verify --network mumbai 0x529abb3a7083d00b6956372475f17B848954aC50 --contract contracts/1delta/proxy/DeltaBorker.sol:DeltaBrokerProxy --constructor-args scripts/verify.js
// npx hardhat verify --network mumbai 0xA83129791403c490FaA787FB0A1f03322256DE7D --contract contracts/1delta/modules/aave/AAVESweeperModule.sol:AAVESweeperModule
// npx hardhat verify --network mumbai 0xf20e318D7D0B33631958ab233ECE11e9B7830DCd --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule


//goerli
// npx hardhat verify --network goerli 0xa8d1C7D918ABc6F112F89A8496962c9A6cdA52d0 --contract contracts/1delta/modules/aave/AAVEMarginTraderModule.sol:AAVEMarginTraderModule
// npx hardhat verify --network goerli 0xc9ea6d976ee5280B777a0c74B986CF3B7CB31f0c --contract contracts/1delta/modules/aave/AAVEMoneyMarketModule.sol:AAVEMoneyMarketModule
// npx hardhat verify --network goerli 0x18828A9E0b5274Eb8EB152d35B17fB8AF1a29325 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/verify.js
// npx hardhat verify --network goerli 0x687cb2dF3461A8ddA00ef5f3608bA8a091c8144e --contract contracts/1delta/modules/aave/AAVESweeperModule.sol:AAVESweeperModule
// npx hardhat verify --network goerli 0xaDDeA1f13e5F8AE790483D14c2bb2d18C40d613b --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule


// matic
// npx hardhat verify --network matic 0xf655538718435f7981098821bE19fcE98477007b --contract contracts/1delta/modules/comet/CometMarginTraderModule.sol:CometMarginTraderModule --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0xFA9f51D2521515C68B67f5638FF764b74980D7Cc --contract contracts/1delta/modules/comet/CometMoneyMarketModule.sol:CometMoneyMarketModule  --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0x18828A9E0b5274Eb8EB152d35B17fB8AF1a29325 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0xaEc49340f7914511eD6D1F8EA8F081647730C74f --contract contracts/1delta/modules/comet/CometSweeperModule.sol:CometSweeperModule --constructor-args scripts/comet/verify.js
// npx hardhat verify --network matic 0x42951aD7Bf54a20E43372dDF5A65BbA7813E19f3 --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule --constructor-args scripts/verify.js


// mumbai comet lens
// npx hardhat verify --network mumbai 0x934E7212656df04E3526f6481277bDA92f082053 --contract contracts/misc/CometLens.sol:CometLens

// npx hardhat verify --network mantle 0x894fc5177d8e670A4EF4C0aDA2FC5C04861b46Ab --contract contracts/1delta/modules/deploy/mantle/FlashAggregator.sol:DeltaFlashAggregatorMantle 

// npx hardhat verify --network mantle 0x4b5458BB47dCBC1a41B31b41e1a8773dE312BE9d --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/verify_mantle.js

// npx hardhat verify --network mantle 0x6Bc6aCB905c1216B0119C87Bf9E178ce298310FA --contract contracts/1delta/modules/aave/ManagementModule.sol:ManagementModule

// npx hardhat verify --network mantle 0x3EdAB7c8E32be3817e5c8612a6F1160a7D67A170 --contract contracts/1delta/modules/aave/MarginTradeDataViewerModule.sol:MarginTradeDataViewerModule

// npx hardhat verify --network mantle 0xCe434378adacC51d54312c872113D687Ac19B516 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule

// npx hardhat verify --network mantle 0x91549bad7A081742dEC72E2CF55a2477A880a798 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule

// npx hardhat verify --network mantle 0x32198Ee619fAd24169fa94A149Cb5205701C6AB1 --contract contracts/1delta/proxy/modules/OwnershipModule.sol:OwnershipModule


// npx hardhat verify --network mantle 0xB2B6Bd4C88124D73dE0ea128c86267AB64Fd1069 --contract contracts/1delta/modules/aave/MarginTradeDataViewerModule.sol:MarginTradeDataViewerModule

// npx hardhat verify --network mantle 0xA453ba397c61B0c292EA3959A858821145B2707F --contract contracts/1delta/initializers/MarginTraderInit.sol:MarginTraderInit --constructor-args scripts/verify_mantle.js
