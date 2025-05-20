
// npx hardhat verify --network arbitrum 0xfca11Db2b5DE60DF9a2C81233333a449983B4101 --contract contracts/1delta/composer/generic/CallForwarder.sol:CallForwarder 

module.exports = [
    "0x3375B2EF9C4D2c6434d39BBE5234c5101218500d", // impl
    '0x999999833d965c275A2C102a4Ebf222ca938546f', // owner
    "0x", // data
];


// npx hardhat verify --network optimism 0xCDef0A216fcEF809258aA4f341dB1A5aB296ea72 --contract contracts/external-protocols/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy  --constructor-args scripts/verify_fw.js
// npx hardhat verify --network optimism 0x5c4F2eACBdc1EB38F839bDDD7620E250a36819D4 --contract contracts/1delta/composer/chains/op/Composer.sol:OneDeltaComposerOp



// npx hardhat verify --network arbitrum 0x05f3f58716a88A52493Be45aA0871c55b3748f18 --contract contracts/external-protocols/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy  --constructor-args scripts/verify_fw.js
// npx hardhat verify --network arbitrum 0xd184c5315B728c1C990f59dDD275c8155f8e255c --contract contracts/1delta/composer/chains/arbitrum-one/Composer.sol:OneDeltaComposerArbitrumOne

// npx hardhat verify --network matic 0xFd245e732b40b6BF2038e42b476bD06580585326 --contract contracts/external-protocols/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy  --constructor-args scripts/verify_fw.js
// npx hardhat verify --network matic 0x1DD5D0659e5e525f85B2d95f846062e55C60f55E --contract contracts/1delta/composer/chains/polygon/Composer.sol:OneDeltaComposerPolygon


// npx hardhat verify --network base 0xB7ea94340e65CC68d1274aE483dfBE593fD6f21e --contract contracts/external-protocols/openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy  --constructor-args scripts/verify_fw.js
// npx hardhat verify --network base 0x3375B2EF9C4D2c6434d39BBE5234c5101218500d --contract contracts/1delta/composer/chains/base/Composer.sol:OneDeltaComposerBase
