// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ChainBase.sol";
import "./Lib.sol";

contract ArbitrumOne is ChainBase {
    constructor() ChainBase(ChainIds.BASE) {
        _setupTokens();
    }

    function _setupTokens() private {
        // Tokens
        tokens[CHAIN_ID][TokenNames.NATIVE] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        tokens[CHAIN_ID][TokenNames.WRAPPED_NATIVE] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        tokens[CHAIN_ID][TokenNames.WETH] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        tokens[CHAIN_ID][TokenNames.USDC] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        tokens[CHAIN_ID][TokenNames.USDT] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        tokens[CHAIN_ID][TokenNames.ARB] = 0x912CE59144191C1204E64559FE8253a0e49E6548;
        tokens[CHAIN_ID][TokenNames.wstETH] = 0x5979D7b546E38E414F7E9822514be443A4800529;
        tokens[CHAIN_ID][TokenNames.weETH] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
        // comptroller
        tokens[CHAIN_ID][TokenNames.VENUS_COMPTROLLER] = 0x317c1A5739F39046E20b08ac9BeEa3f10fD43326;
        tokens[CHAIN_ID][TokenNames.VENUS_ETH_COMPTROLLER] = 0x52bAB1aF7Ff770551BD05b9FC2329a0Bf5E23F16;
        // collaterals
        VENUS_cTokens[0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f] = 0xaDa57840B372D4c28623E87FC175dE8490792811;
        VENUS_cTokens[0x82aF49447D8a07e3bd95BD0d56f35241523fBab1] = 0x68a34332983f4Bf866768DD6D6E638b02eF5e1f0;
        VENUS_cTokens[0xaf88d065e77c8cC2239327C5EDb3A432268e5831] = 0x7D8609f8da70fF9027E9bc5229Af4F6727662707;
        VENUS_cTokens[0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9] = 0xB9F9117d4200dC296F9AcD1e8bE1937df834a2fD;
        VENUS_cTokens[0x912CE59144191C1204E64559FE8253a0e49E6548] = 0xAeB0FEd69354f34831fe1D16475D9A83ddaCaDA6;
        VENUS_cTokens[0x70d95587d40A2caf56bd97485aB3Eec10Bee6336] = 0x9bb8cEc9C0d46F53b4f2173BB2A0221F66c353cC;
        VENUS_cTokens[0x47c031236e19d024b42f8AE6780E44A573170703] = 0x4f3a73f318C5EA67A86eaaCE24309F29f89900dF;
        VENUS_ETH_cTokens[0x5979D7b546E38E414F7E9822514be443A4800529] = 0x9df6B5132135f14719696bBAe3C54BAb272fDb16;
        VENUS_ETH_cTokens[0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe] = 0x246a35E79a3a0618535A469aDaF5091cAA9f7E88;
        VENUS_ETH_cTokens[0x82aF49447D8a07e3bd95BD0d56f35241523fBab1] = 0x39D6d13Ea59548637104E40e729E4aABE27FE106;
    }

    function getRpcUrl() public pure override returns (string memory) {
        return "https://arbitrum.drpc.org";
    }

    function getForkBlock() public pure override returns (uint256) {
        return 290934482;
    }
}
