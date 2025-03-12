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

        // USDC
        tokens[CHAIN_ID][TokenNames.USDC] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens[CHAIN_ID][TokenNames.AaveV2_USDC] = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
        tokens[CHAIN_ID][TokenNames.AaveV3_USDC] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
        tokens[CHAIN_ID][TokenNames.CompV2_USDC] = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

        tokens[CHAIN_ID][TokenNames.AaveV2_Pool] = 0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C;
        tokens[CHAIN_ID][TokenNames.AaveV3_Pool] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

        tokens[CHAIN_ID][TokenNames.COMPTROLLER] = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function getRpcUrl() public pure override returns (string memory) {
        return "https://api.avax.network/ext/bc/C/rpc";
    }

    function getForkBlock() public pure override returns (uint256) {
        return 58625200;
    }
}
