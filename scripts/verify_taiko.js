module.exports = [
  '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
  "0xcB6Eb8df68153cebF60E1872273Ef52075a5C297", // config
];



// npx hardhat verify --network taiko 0xcB6Eb8df68153cebF60E1872273Ef52075a5C297 --contract contracts/1delta/proxy/modules/ConfigModule.sol:ConfigModule
// npx hardhat verify --network taiko 0x7a59ddbB76521E8982Fa3A08598C9a83b14A6C07 --contract contracts/1delta/proxy/modules/LensModule.sol:LensModule
// npx hardhat verify --network taiko 0x0bd7473CbBf81d9dD936c61117eD230d95006CA2 --contract contracts/1delta/proxy/DeltaBrokerGen2.sol:DeltaBrokerProxyGen2 --constructor-args scripts/verify_taiko.js
// npx hardhat verify --network taiko 0x9DAD187fb96DdFf93a1946A583F8b5B73C055Cbf --contract contracts/1delta/modules/taiko/Composer.sol:OneDeltaComposerTaiko 
// npx hardhat verify --network taiko 0xaCF4079C0D5D4a4Da3609E45881fDeFb58751C1A --contract contracts/1delta/modules/shared/storage/ManagementModule.sol:ManagementModule 
