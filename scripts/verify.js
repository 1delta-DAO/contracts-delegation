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
  //   "0xb92028D62D69a24Fc2A52Fe29CD21432Dd0504a5", // config
  // ];

  // inp with factory
  // module.exports = [
  //   '0x1F98431c8aD98523631AE4a59f267346ea31F984', // uni factory
  //   '0x794a61358D6845594F94dc1DB02A252b5b4814aD', // aave pool
  // ];

  // flash modules
  module.exports = [
    '0x794a61358D6845594F94dc1DB02A252b5b4814aD', // aave pool
    '0xBA12222222228d8Ba445958a75a0704d566BF2C8'// balancer
  ];
  // npx hardhat verify --network matic 0x3011271f49E0eA9D481cf0c0a6d343b458107F4c --contract contracts/1delta/modules/aave/AAVEFlashModule.sol:AAVEFlashModule --constructor-args scripts/verify.js
// npx hardhat verify --network matic 0xD4F433941EC1A1e8878a9A13cfd9afea0a34509C --contract contracts/1delta/modules/aave/BalancerFlashModule.sol:BalancerFlashModule --constructor-args scripts/verify.js

    // mumbai
    // npx hardhat verify --network mumbai 0xE0d077f7C0d87909A939160EDae002cC9f33168f --contract contracts/1delta/modules/aave/AAVEMarginTraderModule.sol:AAVEMarginTraderModule
    // npx hardhat verify --network mumbai 0xAA71A440e4ea9Bd108e06b556A16C60c610aFdf9 --contract contracts/1delta/modules/aave/AAVEMoneyMarketModule.sol:AAVEMoneyMarketModule
    // npx hardhat verify --network mumbai 0x529abb3a7083d00b6956372475f17B848954aC50 --contract contracts/1delta/proxy/DeltaBorker.sol:DeltaBrokerProxy --constructor-args scripts/verify.js
    // npx hardhat verify --network mumbai 0xA83129791403c490FaA787FB0A1f03322256DE7D --contract contracts/1delta/modules/aave/AAVESweeperModule.sol:AAVESweeperModule
    // npx hardhat verify --network mumbai 0xf20e318D7D0B33631958ab233ECE11e9B7830DCd --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule


    //goerli
    // npx hardhat verify --network goerli 0xa8d1C7D918ABc6F112F89A8496962c9A6cdA52d0 --contract contracts/1delta/modules/aave/AAVEMarginTraderModule.sol:AAVEMarginTraderModule
    // npx hardhat verify --network goerli 0xc9ea6d976ee5280B777a0c74B986CF3B7CB31f0c --contract contracts/1delta/modules/aave/AAVEMoneyMarketModule.sol:AAVEMoneyMarketModule
    // npx hardhat verify --network goerli 0x0C233b11F886da1D5206Fa9e0d48293c23A4fDb9 --contract contracts/1delta/proxy/DeltaBorker.sol:DeltaBrokerProxy --constructor-args scripts/verify.js
    // npx hardhat verify --network goerli 0x687cb2dF3461A8ddA00ef5f3608bA8a091c8144e --contract contracts/1delta/modules/aave/AAVESweeperModule.sol:AAVESweeperModule
    // npx hardhat verify --network goerli 0xaDDeA1f13e5F8AE790483D14c2bb2d18C40d613b --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule


   // matic
    // npx hardhat verify --network matic 0xf655538718435f7981098821bE19fcE98477007b --contract contracts/1delta/modules/comet/CometMarginTraderModule.sol:CometMarginTraderModule --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0xFA9f51D2521515C68B67f5638FF764b74980D7Cc --contract contracts/1delta/modules/comet/CometMoneyMarketModule.sol:CometMoneyMarketModule  --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0x04555b0B7367315cdaDe1E1889FA4FCdd27b66D6 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0xaEc49340f7914511eD6D1F8EA8F081647730C74f --contract contracts/1delta/modules/comet/CometSweeperModule.sol:CometSweeperModule --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0x42951aD7Bf54a20E43372dDF5A65BbA7813E19f3 --contract contracts/1delta/modules/aave/UniswapV3SwapCallbackModule.sol:UniswapV3SwapCallbackModule --constructor-args scripts/verify.js


    // mumbai comet lens
    // npx hardhat verify --network mumbai 0x934E7212656df04E3526f6481277bDA92f082053 --contract contracts/misc/CometLens.sol:CometLens