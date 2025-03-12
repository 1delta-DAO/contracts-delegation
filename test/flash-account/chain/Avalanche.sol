// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ChainBase.sol";
import "./Lib.sol";

contract Avalanche is ChainBase {
    constructor() ChainBase(ChainIds.AVALANCHE) {
        _setupTokens();
    }

    function _setupTokens() private {
        // AVAX/WAVAX
        tokens[CHAIN_ID][TokenNames.NATIVE] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        tokens[CHAIN_ID][TokenNames.WRAPPED_NATIVE] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        tokens[CHAIN_ID][TokenNames.CompV2_ETH] = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

        // USDC
        tokens[CHAIN_ID][TokenNames.USDC] = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
        tokens[CHAIN_ID][TokenNames.AaveV2_USDC] = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
        tokens[CHAIN_ID][TokenNames.AaveV3_USDC] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
        tokens[CHAIN_ID][TokenNames.CompV2_USDC] = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;

        tokens[CHAIN_ID][TokenNames.AaveV2_Pool] = 0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C;
        tokens[CHAIN_ID][TokenNames.AaveV3_Pool] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

        tokens[CHAIN_ID][TokenNames.COMPTROLLER] = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    }

    function getRpcUrl() public pure override returns (string memory) {
        return "https://api.avax.network/ext/bc/C/rpc";
    }

    function getForkBlock() public pure override returns (uint256) {
        return 58625200;
    }
}
