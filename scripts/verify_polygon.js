module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528", // config
];



// npx hardhat verify --network matic 0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network matic 0xAC694778b869e2a4c1702C5BADf2B192Cfe83750 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network matic 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4 --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_polygon.js
// npx hardhat verify --network matic 0x627b69E4f1719E19db01F25Be24BD4099df84670 --contract contracts/1delta/modules/deploy/polygon/Composer.sol:OneDeltaComposerPolygon 
// npx hardhat verify --network matic 0x025fD6E2e235329daFf6b29DD6DA7CDD38b22De5 --contract contracts/1delta/modules/deploy/polygon/storage/ManagementModule.sol:PolygonManagementModule 
