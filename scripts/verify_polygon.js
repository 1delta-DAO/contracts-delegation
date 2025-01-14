module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528", // config
];



// npx hardhat verify --network matic 0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network matic 0xAC694778b869e2a4c1702C5BADf2B192Cfe83750 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network matic 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4 --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_polygon.js
// npx hardhat verify --network matic 0xA018227F40c8807B50156e2f08A49B6Ed2B1fd84 --contract contracts/1delta/modules/polygon/Composer.sol:OneDeltaComposerPolygon 
// npx hardhat verify --network matic 0xa1B95bC2b62e39d9CFD4A020EB857eFAc8A84d33 --contract contracts/1delta/modules/shared/storage/ManagementModule.sol:ManagementModule  
// npx hardhat verify --network matic 0xCdFAAf881359C61DCF8BF4fd87622330246633DA --contract contracts/1delta/modules/shared/MetaAggregator.sol:DeltaMetaAggregator