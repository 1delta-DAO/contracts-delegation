module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xf9438f2b1c63D8dAC24311256F5483D7f7575863", // config
];



// npx hardhat verify --network arbitrum 0xf9438f2b1c63D8dAC24311256F5483D7f7575863 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network arbitrum 0xcB6Eb8df68153cebF60E1872273Ef52075a5C297 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network arbitrum 0x816EBC5cb8A5651C902Cb06659907A93E574Db0B --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_arbitrum.js
// npx hardhat verify --network arbitrum 0xB7ea94340e65CC68d1274aE483dfBE593fD6f21e --contract contracts/1delta/modules/arbitrum/Composer.sol:OneDeltaComposerArbitrum 
// npx hardhat verify --network arbitrum 0x5380932B5Fb39A174CBC6074d152e15d70F4A39f --contract contracts/1delta/modules/shared/storage/ManagementModule.sol:ManagementModule 

// npx hardhat verify --network arbitrum 0x925716D57c842B50806884EDb295bA3E3A8EBdFE --contract contracts/1delta/proxy/modules/OwnershipModule.sol:OwnershipModule