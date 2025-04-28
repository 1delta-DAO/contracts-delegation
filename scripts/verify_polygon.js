module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528", // config
];



// npx hardhat verify --network matic 0xFc7c0Deb7012EF6e930bF681D7C7cF854eC8E528 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network matic 0xAC694778b869e2a4c1702C5BADf2B192Cfe83750 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network matic 0x75864a5d4a1c41A8766dAe30871b404F73865925 --contract contracts/1delta/proxy/modules/OwnershipModule.sol:OwnershipModule
// npx hardhat verify --network matic 0x6A6faa54B9238f0F079C8e6CBa08a7b9776C7fE4 --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_polygon.js
// npx hardhat verify --network matic 0x3cCe6f08B9e1707D51De7090D9ee80428279FE10 --contract contracts/1delta/modules/polygon/Composer.sol:OneDeltaComposerPolygon 
// npx hardhat verify --network matic 0xa1B95bC2b62e39d9CFD4A020EB857eFAc8A84d33 --contract contracts/1delta/contracts/1delta/shared/storage/ManagementModule.sol:ManagementModule  
// npx hardhat verify --network matic 0xCdFAAf881359C61DCF8BF4fd87622330246633DA --contract contracts/1delta/contracts/1delta/shared/MetaAggregator.sol:DeltaMetaAggregator


// npx hardhat verify --network matic 0x4eDA401658c5286d16c4d342884F32280B4E8b1b --contract contracts/misc/CometLens.sol:CometLens