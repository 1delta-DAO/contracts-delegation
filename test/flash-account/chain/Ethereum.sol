// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "./ChainBase.sol";
import "./Lib.sol";
contract Ethereum is ChainBase {
    constructor() ChainBase(ChainIds.ETHEREUM) {
        _setupTokens();
    }

    function _setupTokens() private {
        // ETH/WETH
        tokens[CHAIN_ID][TokenNames.NATIVE] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        tokens[CHAIN_ID][TokenNames.WRAPPED_NATIVE] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens[CHAIN_ID][TokenNames.AaveV2_ETH] = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
        tokens[CHAIN_ID][TokenNames.AaveV3_ETH] = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;

        // USDC
        tokens[CHAIN_ID][TokenNames.USDC] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens[CHAIN_ID][TokenNames.AaveV2_USDC] = 0xBcca60bB61934080951369a648Fb03DF4F96263C;
        tokens[CHAIN_ID][TokenNames.AaveV3_USDC] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
        tokens[CHAIN_ID][TokenNames.CompV2_USDC] = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;

        tokens[CHAIN_ID][TokenNames.AaveV2_Pool] = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
        tokens[CHAIN_ID][TokenNames.AaveV3_Pool] = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

        tokens[CHAIN_ID][TokenNames.COMPTROLLER] = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    }

    function getRpcUrl() public pure override returns (string memory) {
        return "https://ethereum-rpc.publicnode.com";
    }

    function getForkBlock() public pure override returns (uint256) {
        return 20_000_000;
    }
}
