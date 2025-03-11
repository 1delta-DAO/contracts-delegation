module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xf9438f2b1c63D8dAC24311256F5483D7f7575863", // config
];



// npx hardhat verify --network hemi 0xf9438f2b1c63D8dAC24311256F5483D7f7575863 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network hemi 0xcB6Eb8df68153cebF60E1872273Ef52075a5C297 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network hemi 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_hemi.js
// npx hardhat verify --network hemi 0x7e2D250E4FD0EeD6BD2cB3DC525A2b9f12508152 --contract contracts/1delta/modules/hemi/Composer.sol:OneDeltaComposerHemi 
// npx hardhat verify --network hemi 0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201 --contract contracts/1delta/modules/shared/storage/ManagementModule.sol:ManagementModule 

// npx hardhat verify --network hemi 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2 --contract contracts/1delta/proxy/modules/OwnershipModule.sol:OwnershipModule