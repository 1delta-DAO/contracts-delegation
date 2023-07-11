 // goerli
//  module.exports = [
//     '0x4d6f46Ff41908A0920986aab432ab4A98E5Cbdeb', // owner
//     "0x93c0774b0e269d4191efb3bdf65645a3722001a8", // config
//   ];


  // mumbai
  // module.exports = [
  //   '0x4d6f46Ff41908A0920986aab432ab4A98E5Cbdeb', // owner
  //   "0x305d700b8211e0b363E4FD76571dcf1f3dB7b0f4", // config
  // ];

  // polygon
  // module.exports = [
  //   '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  //   "0xb92028D62D69a24Fc2A52Fe29CD21432Dd0504a5", // config
  // ];

  // inp with factory
  module.exports = [
    '0x1F98431c8aD98523631AE4a59f267346ea31F984', // uni factory
  ];

    // mumbai
    // npx hardhat verify --network mumbai 0x01D8853Fd8C78B2c26097B5003184037F219F77a --contract contracts/1delta/modules/comet/CometMarginTraderModule.sol:CometMarginTraderModule
    // npx hardhat verify --network mumbai 0xCe9A6D29d57c409881ea284b457e97e3b7F77231 --contract contracts/1delta/modules/comet/CometMoneyMarketModule.sol:CometMoneyMarketModule
    // npx hardhat verify --network mumbai 0x178E4EB141BBaEAcd56DAE120693D48d4B5f198d --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network mumbai 0x2f15ec1A5d5ad08cbf4E64d2a6cAFE4F5ff5117B --contract contracts/1delta/modules/comet/CometSweeperModule.sol:CometSweeperModule
    // npx hardhat verify --network mumbai 0xDe7194b4804a669e2B16b896fDF0b829e33f3317 --contract contracts/1delta/modules/comet/CometUniV3Callback.sol:CometUniV3Callback


   // matic
    // npx hardhat verify --network matic 0xf655538718435f7981098821bE19fcE98477007b --contract contracts/1delta/modules/comet/CometMarginTraderModule.sol:CometMarginTraderModule --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0xF443a1F74e9eeEa693743ed23a85279fef279187 --contract contracts/1delta/modules/comet/CometMoneyMarketModule.sol:CometMoneyMarketModule  --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0x04555b0B7367315cdaDe1E1889FA4FCdd27b66D6 --contract contracts/1delta/proxy/DeltaBroker.sol:DeltaBrokerProxy --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0x5763e18f9CfB220d1b23f89701142Fdd18C1f223 --contract contracts/1delta/modules/comet/CometSweeperModule.sol:CometSweeperModule --constructor-args scripts/comet/verify.js
    // npx hardhat verify --network matic 0x53a9c8E308d4858d3a49076058656975fC1BEA96 --contract contracts/1delta/modules/comet/CometUniV3Callback.sol:CometUniV3Callback --constructor-args scripts/comet/verify.js


    // mumbai comet lens
    // npx hardhat verify --network mumbai 0x934E7212656df04E3526f6481277bDA92f082053 --contract contracts/misc/CometLens.sol:CometLens

     // matic comet lens
    // npx hardhat verify --network matic 0x47B087eBeD0d5a2Eb93034D8239a5B89d0ddD990 --contract contracts/misc/CometLens.sol:CometLens