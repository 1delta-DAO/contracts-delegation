module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528", // config
];



// npx hardhat verify --network matic 0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network matic 0xAC694778b869e2a4c1702C5BADf2B192Cfe83750 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network matic 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4 --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_polygon.js
// npx hardhat verify --network matic 0x1bD60a4b301C28A03501a1A5F909890489EF616B --contract contracts/1delta/modules/polygon/Composer.sol:OneDeltaComposerPolygon 
// npx hardhat verify --network matic 0x025fD6E2e235329daFf6b29DD6DA7CDD38b22De5 --contract contracts/1delta/modules/polygon/storage/ManagementModule.sol:PolygonManagementModule 
// npx hardhat verify --network matic 0xCdFAAf881359C61DCF8BF4fd87622330246633DA --contract contracts/1delta/modules/shared/MetaAggregator.sol:DeltaMetaAggregator