// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

struct AaveTokens {
    address aToken;
    address vToken;
    address sToken;
}

contract AAVE_V3_DATA_8453 {
    mapping(address => AaveTokens) lendingTokens;

    constructor() {
        lendingTokens[0x4200000000000000000000000000000000000006] = AaveTokens(
            0xD4a0e0b9149BCee3C920d2E00b5dE09138fd8bb7,
            0x24e6e0795b3c7c71D965fCc4f371803d1c1DcA1E,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22] = AaveTokens(
            0xcf3D55c10DB69f28fD1A75Bd73f3D8A2d9c595ad,
            0x1DabC36f19909425f654777249815c073E8Fd79F,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA] = AaveTokens(
            0x0a1d576f3eFeF75b330424287a95A366e8281D54,
            0x7376b2F323dC56fCd4C191B34163ac8a84702DAB,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452] = AaveTokens(
            0x99CBC45ea5bb7eF3a5BC08FB1B7E56bB2442Ef0D,
            0x41A7C3f5904ad176dACbb1D99101F59ef0811DC1,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913] = AaveTokens(
            0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB,
            0x59dca05b6c26dbd64b5381374aAaC5CD05644C28,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A] = AaveTokens(
            0x7C307e128efA31F540F2E2d976C995E0B65F51F6,
            0x8D2e3F1f4b38AA9f1ceD22ac06019c7561B03901,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf] = AaveTokens(
            0xBdb9300b7CDE636d9cD4AFF00f6F009fFBBc8EE6,
            0x05e08702028de6AaD395DC6478b554a56920b9AD,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0x2416092f143378750bb29b79eD961ab195CcEea5] = AaveTokens(
            0xDD5745756C2de109183c6B5bB886F9207bEF114D,
            0xbc4f5631f2843488792e4F1660d0A51Ba489bdBd,
            0x0000000000000000000000000000000000000000
        );
        lendingTokens[0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee] = AaveTokens(
            0x067ae75628177FD257c2B1e500993e1a0baBcBd1,
            0x38e59ADE183BbEb94583d44213c8f3297e9933e9,
            0x0000000000000000000000000000000000000000
        );
    }

    address internal constant AAVE_V3_POOL = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address internal constant USDbC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address internal constant wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant GHO = 0x6Bb7a212910682DCFdbd5BCBb3e28FB4E8da10Ee;
}
