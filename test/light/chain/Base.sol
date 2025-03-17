// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./ChainBase.sol";
import "./Lib.sol";

contract Base is ChainBase {
    constructor() ChainBase(ChainIds.BASE) {
        _setupTokens();
    }

    function getRpcUrl() public pure override returns (string memory) {
        return "https://mainnet.base.org";
    }

    function getForkBlock() public pure override returns (uint256) {
        return 26696865;
    }

    function _setupTokens() private {
        // Tokens
        _initTokens();

        // Aave V3
        _initAaveV3LendingTokens();

        // Compound V3
        _initCompoundV3Tokens();

        // Granary
        _initGranaryLendingTokens();

        // Morpho
        _initMorphoTokens();
    }

    function _initTokens() private {
        tokens[CHAIN_ID][TokenNames.NATIVE] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        tokens[CHAIN_ID][TokenNames.WRAPPED_NATIVE] = 0x4200000000000000000000000000000000000006;
        tokens[CHAIN_ID][TokenNames.WETH] = 0x4200000000000000000000000000000000000006;
        tokens[CHAIN_ID][TokenNames.USDC] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        tokens[CHAIN_ID][TokenNames.cbETH] = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
        tokens[CHAIN_ID][TokenNames.USDbC] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
        tokens[CHAIN_ID][TokenNames.wstETH] = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
        tokens[CHAIN_ID][TokenNames.weETH] = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
        tokens[CHAIN_ID][TokenNames.cbBTC] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
        tokens[CHAIN_ID][TokenNames.ezETH] = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        tokens[CHAIN_ID][TokenNames.GHO] = 0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee;
        tokens[CHAIN_ID][TokenNames.LBTC] = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
        tokens[CHAIN_ID][TokenNames.wrsETH] = 0xEDfa23602D0EC14714057867A78d01e94176BEA0;
        tokens[CHAIN_ID][TokenNames.AERO] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
        tokens[CHAIN_ID][TokenNames.DAI] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    }

    function _initAaveV3LendingTokens() private {
        tokens[CHAIN_ID][TokenNames.AaveV3_Pool] = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

        AaveV3LendingTokens[0x4200000000000000000000000000000000000006] = AaveTokens(
            0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7,
            0x24e6e0795b3c7c71D965fCc4f371803d1c1DcA1E,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22] = AaveTokens(
            0xcf3D55c10DB69f28fD1A75Bd73f3D8A2d9c595ad,
            0x1DabC36f19909425f654777249815c073E8Fd79F,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA] = AaveTokens(
            0x0a1d576f3eFeF75b330424287a95A366e8281D54,
            0x7376b2F323dC56fCd4C191B34163ac8a84702DAB,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452] = AaveTokens(
            0x99CBC45ea5bb7eF3a5BC08FB1B7E56bB2442Ef0D,
            0x41A7C3f5904ad176dACbb1D99101F59ef0811DC1,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913] = AaveTokens(
            0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB,
            0x59dca05b6c26dbd64b5381374aAaC5CD05644C28,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A] = AaveTokens(
            0x7C307e128efA31F540F2E2d976C995E0B65F51F6,
            0x8D2e3F1f4b38AA9f1ceD22ac06019c7561B03901,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf] = AaveTokens(
            0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6,
            0x05e08702028de6AaD395DC6478b554a56920b9AD,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0x2416092f143378750bb29b79eD961ab195CcEea5] = AaveTokens(
            0xDD5745756C2de109183c6B5bB886F9207bEF114D,
            0xbc4f5631f2843488792e4F1660d0A51Ba489bdBd,
            0x0000000000000000000000000000000000000000
        );
        AaveV3LendingTokens[0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee] = AaveTokens(
            0x067ae75628177FD257c2B1e500993e1a0baBcBd1,
            0x38e59ADE183BbEb94583d44213c8f3297e9933e9,
            0x0000000000000000000000000000000000000000
        );
    }

    function _initCompoundV3Tokens() private {
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_USDC_BASE] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_USDC_COMET] = 0xb125E6687d4313864e53df431d5425969c15Eb2F;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_USDBC_BASE] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_USDBC_COMET] = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_WETH_BASE] = 0x4200000000000000000000000000000000000006;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_WETH_COMET] = 0x46e6b214b524310239732D51387075E0e70970bf;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_AERO_BASE] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
        tokens[CHAIN_ID][TokenNames.COMPOUND_V3_AERO_COMET] = 0x784efeB622244d2348d4F2522f8860B96fbEcE89;

        CometToBase[0xb125E6687d4313864e53df431d5425969c15Eb2F] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
        CometToBase[0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
        CometToBase[0x46e6b214b524310239732D51387075E0e70970bf] = 0x4200000000000000000000000000000000000006;
        CometToBase[0x784efeB622244d2348d4F2522f8860B96fbEcE89] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    }

    function _initGranaryLendingTokens() private {
        tokens[CHAIN_ID][TokenNames.GRANARY_POOL] = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;

        GraneryLendingTokens[0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb] = AaveTokens(
            0xe7334Ad0e325139329E747cF2Fc24538dD564987,
            0xe5415Fa763489C813694D7A79d133F0A7363310C,
            0xC40709470139657E6D80249c5cC998eFb44898C9
        );
        GraneryLendingTokens[0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA] = AaveTokens(
            0x02CD18c03b5b3f250d2B29C87949CDAB4Ee11488,
            0xBcE07537DF8AD5519C1d65e902e10aA48AF83d88,
            0x73C177510cb7b5c6a7C770376Fc6EBD29eF9e1A7
        );
        GraneryLendingTokens[0x4200000000000000000000000000000000000006] = AaveTokens(
            0x9c29a8eC901DBec4fFf165cD57D4f9E03D4838f7,
            0x06D38c309d1dC541a23b0025B35d163c25754288,
            0x6f66C5C5e2FF94929582EaBfc19051F19ed9EB70
        );
        GraneryLendingTokens[0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22] = AaveTokens(
            0x272CfCceFbEFBe1518cd87002A8F9dfd8845A6c4,
            0x5eEA43129024eeE861481f32c2541b12DDD44c08,
            0x09AB5cA2d537b81520F78474d6ED43675451A7f8
        );
        GraneryLendingTokens[0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf] = AaveTokens(
            0x58254000eE8127288387b04ce70292B56098D55C,
            0x05249f9Ba88F7d98fe21a8f3C460f4746689Aea5,
            0xc73AC4D26025622167a2BC67C93a855C1c6BDb24
        );
        GraneryLendingTokens[0x940181a94A35A4569E4529A3CDfB74e38FD98631] = AaveTokens(
            0xe3f709397e87032E61f4248f53Ee5c9a9aBb6440,
            0x083E519E76fe7e68C15A6163279eAAf87E2addAE,
            0x383995FD2E86a2e067Ffb31674aa0d1B370B39bD
        );
        GraneryLendingTokens[0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913] = AaveTokens(
            0xC17312076F48764d6b4D263eFdd5A30833E311DC,
            0x3F332f38926b809670b3cac52Df67706856a1555,
            0x5183adca8472B7c999c310e4D5aAab04ad12E252
        );
    }

    function _initMorphoTokens() private {
        tokens[CHAIN_ID][TokenNames.META_MORPHO_USDC] = 0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A;
        tokens[CHAIN_ID][TokenNames.MORPHO] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    }
}
