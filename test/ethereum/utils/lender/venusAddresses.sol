// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

library VenusEthereumAddresses {
    address internal constant PoolRegistry = 0x61CAff113CCaf05FFc6540302c37adcf077C5179;

    address internal constant PoolLens = 0x57bea400aE7E51855a2e1E1523475d9d2eB0742F;

    address internal constant DefaultProxyAdmin = 0x567e4Cc5E085d09F66F836fa8279F38B4E5866b9;

    address internal constant Comptroller_Impl = 0xAE2C3F21896c02510aA187BdA0791cDA77083708;

    address internal constant VToken = 0xfc08aADC7a1A93857f6296C3fb78aBA1d286533a;

    address internal constant ProtocolShareReserve = 0x8c8c8530464f7D95552A11eC31Adbd4dC4AC4d3E;

    // Core pool

    address internal constant Comptroller = 0x687a01ecF6d3907658f7A7c714749fAC32336D1B;

    address internal constant NativeTokenGateway = 0x044dd75b9E043ACFD2d6EB56b6BB814df2a9c809;

    // Underlying tokens:

    address internal constant crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;

    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address internal constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    address internal constant sFRAX = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32;

    address internal constant TUSD = 0x0000000000085d4780B73119b644AE5ecd22b376;

    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // Markets:

    address internal constant vcrvUSD_Core = 0x672208C10aaAA2F9A6719F449C4C8227bc0BC202;

    address internal constant vDAI_Core = 0xd8AdD9B41D4E1cd64Edad8722AB0bA8D35536657;

    address internal constant vFRAX_Core = 0x4fAfbDc4F2a9876Bd1764827b26fb8dc4FD1dB95;

    address internal constant vsFRAX_Core = 0x17142a05fe678e9584FA1d88EfAC1bF181bF7ABe;

    address internal constant vTUSD_Core = 0x13eB80FDBe5C5f4a7039728E258A6f05fb3B912b;

    address internal constant vUSDC_Core = 0x17C07e0c232f2f80DfDbd7a95b942D893A4C5ACb;

    address internal constant vUSDT_Core = 0x8C3e3821259B82fFb32B2450A95d2dcbf161C24E;

    address internal constant vWBTC_Core = 0x8716554364f20BCA783cb2BAA744d39361fd1D8d;

    address internal constant vWETH_Core = 0x7c8ff7d2A1372433726f879BD945fFb250B94c65;

    // Pool Curve
    address internal constant Comptroller_CURVE_POOL = 0x67aA3eCc5831a65A5Ba7be76BED3B5dc7DB60796;

    // Underlying tokens:

    // address internal constant crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;

    address internal constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    // Markets:

    address internal constant vcrvUSD_Curve = 0x2d499800239C4CD3012473Cb1EAE33562F0A6933;

    address internal constant vCRV_Curve = 0x30aD10Bd5Be62CAb37863C2BfcC6E8fb4fD85BDa;

    // Pool Liquid Staked ETH
    address internal constant Comptroller_ETH_POOL = 0xF522cd0360EF8c2FF48B648d53EA1717Ec0F3Ac3;

    address internal constant NativeTokenGateway_ETH_POOL = 0xBC1471308eb2287eBE137420Eb1664A964895D21;

    // Underlying tokens:

    address internal constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;

    address internal constant PTweETH_26DEC2024 = 0x6ee2b5E19ECBa773a352E5B21415Dc419A700d1d;

    address internal constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;

    address internal constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;

    // address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address internal constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;

    // Markets:

    address internal constant vezETH_LiquidStakedETH = 0xA854D35664c658280fFf27B6eDC6C4195c3229B3;

    address internal constant vPT_weETH_26DEC2024_LiquidStakedETH = 0x76697f8eaeA4bE01C678376aAb97498Ee8f80D5C;

    address internal constant vrsETH_LiquidStakedETH = 0xDB6C345f864883a8F4cae87852Ac342589E76D1B;

    address internal constant vsfrxETH_LiquidStakedETH = 0xF9E9Fe17C00a8B96a8ac20c4E344C8688D7b947E;

    address internal constant vWETH_LiquidStakedETH = 0xc82780Db1257C788F262FBbDA960B3706Dfdcaf2;

    address internal constant vwstETH_LiquidStakedETH = 0x4a240F0ee138697726C8a3E43eFE6Ac3593432CB;

    address internal constant vweETH_LiquidStakedETH = 0xb4933AF59868986316Ed37fa865C829Eba2df0C7;
}
