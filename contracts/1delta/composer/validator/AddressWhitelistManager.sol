// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import "./AddressWhitelistManagerStorage.sol";

contract AddressWhitelistManager is AddressWhitelistManagerStorage {
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        address previousOwner = owner;
        owner = newOwner;
    }

    // Whitelisting the addresses

    function setAaveV2PoolWhitelist(address pool, bool whitelisted) external onlyOwner {
        whitelistedAaveV2Pools[pool] = whitelisted;
    }

    function setAaveV3PoolWhitelist(address pool, bool whitelisted) external onlyOwner {
        whitelistedAaveV3Pools[pool] = whitelisted;
    }

    function setCompoundV2CTokenWhitelist(address cToken, bool whitelisted) external onlyOwner {
        whitelistedCompoundV2CTokens[cToken] = whitelisted;
    }

    function setCompoundV3CometWhitelist(address comet, bool whitelisted) external onlyOwner {
        whitelistedCompoundV3Comets[comet] = whitelisted;
    }

    function setMorphoWhitelist(address morpho, bool whitelisted) external onlyOwner {
        whitelistedMorphos[morpho] = whitelisted;
    }

    function setCallForwarderWhitelist(address callForwarder, bool whitelisted) external onlyOwner {
        whitelistedCallForwarders[callForwarder] = whitelisted;
    }

    // View Functions

    function isAaveV2PoolWhitelisted(address pool) external view returns (bool) {
        return whitelistedAaveV2Pools[pool];
    }

    function isAaveV3PoolWhitelisted(address pool) external view returns (bool) {
        return whitelistedAaveV3Pools[pool];
    }

    function isCompoundV2CTokenWhitelisted(address cToken) external view returns (bool) {
        return whitelistedCompoundV2CTokens[cToken];
    }

    function isCompoundV3CometWhitelisted(address comet) external view returns (bool) {
        return whitelistedCompoundV3Comets[comet];
    }

    function isMorphoWhitelisted(address morpho) external view returns (bool) {
        return whitelistedMorphos[morpho];
    }

    function isCallForwarderWhitelisted(address callForwarder) external view returns (bool) {
        return whitelistedCallForwarders[callForwarder];
    }
}
