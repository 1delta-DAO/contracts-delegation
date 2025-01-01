// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesArbitrum {
    // assets

    address internal WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

    // users
    address internal testUser = 0x5f6f935A9a69F886Dc0147904D0F455ABaC67e14;

    address internal constant WOO_POOL = 0xEd9e3f98bBed560e66B89AaC922E29D4596A9642;

    address internal constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address internal constant YLDR_POOL = 0x8183D4e0561cBdc6acC0Bdb963c352606A2Fa76F;
    
    address internal constant COMET_USDT = 0xd98Be00b5D27fc98112BdE293e487f8D4cA57d07;
    address internal constant COMET_USDC = 0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf;
    address internal constant COMET_WETH = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486;
    address internal constant COMET_USDCE = 0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA;

    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;

    address internal constant CRV_3_USD_AAVE_POOL = 0x445FE580eF8d70FF569aB36e80c647af338db351;
    address internal constant CRV_TRICRYPTO_ZAP = 0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8;
    address internal constant CRV_FACTORY_ZAP = 0x3d8EADb739D1Ef95dd53D718e4810721837c69c1;
    address internal constant CRV_CRV_FACTORY_POOL = 0xc7c939A474CB10EB837894D1ed1a77C61B268Fa7;
    address internal constant CRV_TRICRYPTO_AAVE_META_POOL = 0x92215849c439E1f8612b6646060B4E3E5ef822cC;

    address internal constant CRV_NG_USDN_CRVUSD = 0x5225010A0AE133B357861782B0B865a48471b2C5;
    address internal constant crvUSD = 0xc4Ce1D6F5D98D65eE25Cf85e9F2E9DcFEe6Cb5d6;

    /** DEFAULTS */

    uint16 DEFAULT_LENDER = 1;
    uint16 AAVE_V3 = 0;
    uint16 AVALON = 1;
    uint16 YLDR = 900;
    uint16 COMPOUND_V3_USDC = 2000;
    
    // Flash loans
    uint8 AAVE_V3_FL = 0;
    uint8 BALANCER_V2 = 0xff;
    uint8 BALANCER_V2_DEXID = 50;

    /** DEX CONFIG */

    uint16 internal DEX_FEE_STABLES = 100;
    uint16 internal DEX_FEE_LOW_MEDIUM = 2500;
    uint16 internal DEX_FEE_LOW_HIGH = 3000;
    uint16 internal DEX_FEE_LOW = 500;
    uint16 internal DEX_FEE_NONE = 0;

    uint16 internal BIN_STEP_LOWEST = 1;
    uint16 internal BIN_STEP_LOW = 10;

    uint8 internal UNI_V3 = 0;
    uint8 internal RETRO = 1;
    uint8 internal SUSHI_V3 = 2;
    uint8 internal ALGEBRA = 3;
    uint8 internal IZUMI = 49;
    uint8 internal CURVE = 60;
    uint8 internal CURVE_NG = 151;
    uint8 internal CURVE_META = 61;

    uint8 internal UNI_V2 = 100;
    uint8 internal QUICK_V2 = 101;
    uint8 internal SUSHI_V2 = 102;
    uint8 internal DFYN = 103;
    uint8 internal POLYCAT = 104;
    uint8 internal APESWAP = 105;
    uint8 internal COMETH = 106;

    uint16 internal UNI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal QUICK_V2_FEE_DENOM = 10000 - 30;
    uint16 internal SUSHI_V2_FEE_DENOM = 10000 - 30;
    uint16 internal DFYN_FEE_DENOM = 10000 - 30;
    uint16 internal POLYCAT_FEE_DENOM = 10000 - 24;
    uint16 internal APESWAP_FEE_DENOM = 10000 - 20;
    uint16 internal COMETH_FEE_DENOM = 10000 - 50;

    uint8 internal WOO_FI = 150;

    /** TRADE TYPE FLAG GETTERS */

    function getOpenExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getOpenExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 2);
    }

    function getCollateralSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCollateralSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 0, 3);
    }

    function getCloseExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getCloseExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 3);
    }

    function getDebtSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }

    function getDebtSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (2, 0, 2);
    }

    address internal constant USDC_A_TOKEN_YLDR = 0xAFcc7719EdfCba9215749c8e399f4E20c9024Cf7;
    address internal constant USDC_V_TOKEN_YLDR = 0x42037D996611eD4378A508F67470fBcED1436555;

    address internal constant USDCn_A_TOKEN_YLDR = 0xd8aB1E396Cfc5d9D7922e2Ca0B9084aB64DD6Cee;
    address internal constant USDCn_V_TOKEN_YLDR = 0x477768d8230F2B914554491414d5e76C73314eD2;

    address internal constant WETH_A_TOKEN_YLDR = 0xD85552A6e8DF8dCe06B157d33B383CE9F5f9aDe2;
    address internal constant WETH_V_TOKEN_YLDR = 0x2Cd174A79F40E67D390C12Ced441b17De70f9765;
    address internal constant USDT_A_TOKEN_YLDR = 0xf309Ada8651891a99B251cAb253aD10895b3D028;
    address internal constant USDT_V_TOKEN_YLDR = 0x9113F0D78bC64712e9560f58DC0749e6ac227fff;

    address internal constant WMATIC_A_TOKEN_YLDR = 0xf6535aa0cD4988855247cbEFa7fbe64E3E78e024;
    address internal constant WMATIC_V_TOKEN_YLDR = 0x23219a2d278E99B0F170ad963d34373069159Ab1;

    address internal constant WBTC_A_TOKEN_YLDR = 0x62B1bf965cc3051c73e0DB6b2025cBC371b6ea9c;
    address internal constant WBTC_V_TOKEN_YLDR = 0x87B98Ef3AE0488fe509a129025988956a8962EDA;

    address internal constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    uint8 internal constant DAI_DECIMALS = 18;

    address internal constant DAI_A_TOKEN_AAVE_V3 = 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE;

    address internal constant DAI_V_TOKEN_AAVE_V3 = 0x8619d80FB0141ba7F184CbF22fd724116D9f7ffC;

    address internal constant DAI_S_TOKEN_AAVE_V3 = 0xd94112B5B62d53C9402e7A60289c6810dEF1dC9B;

    address internal constant DAI_INTEREST_RATE_STRATEGY = 0xd56eE97960b1b2953e751151Fd84888cF3F3b521;

    address internal constant DAI_STATA_TOKEN_AAVE_V3 = 0x83c59636e602787A6EEbBdA2915217B416193FcB;

    address internal constant LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;

    uint8 internal constant LINK_DECIMALS = 18;

    address internal constant LINK_A_TOKEN_AAVE_V3 = 0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530;

    address internal constant LINK_V_TOKEN_AAVE_V3 = 0x953A573793604aF8d41F306FEb8274190dB4aE0e;

    address internal constant LINK_S_TOKEN_AAVE_V3 = 0x89D976629b7055ff1ca02b927BA3e020F22A44e4;

    address internal constant LINK_INTEREST_RATE_STRATEGY = 0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

    address internal constant LINK_STATA_TOKEN_AAVE_V3 = 0x37868a45c6741616F9E5a189dC0481AD70056B6a;

    address internal constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

    uint8 internal constant USDC_DECIMALS = 6;

    address internal constant USDC_A_TOKEN_AAVE_V3 = 0x625E7708f30cA75bfd92586e17077590C60eb4cD;

    address internal constant USDC_V_TOKEN_AAVE_V3 = 0xFCCf3cAbbe80101232d343252614b6A3eE81C989;

    address internal constant USDC_S_TOKEN_AAVE_V3 = 0x307ffe186F84a3bc2613D1eA417A5737D69A7007;

    address internal constant USDC_INTEREST_RATE_STRATEGY = 0xc7b53C7d24164FB78F57Ea3b5d056bD2E541013d;

    address internal constant USDC_STATA_TOKEN_AAVE_V3 = 0x1017F4a86Fc3A3c824346d0b8C5e96A5029bDAf9;

    address internal constant WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

    uint8 internal constant WBTC_DECIMALS = 8;

    address internal constant WBTC_A_TOKEN_AAVE_V3 = 0x078f358208685046a11C85e8ad32895DED33A249;

    address internal constant WBTC_V_TOKEN_AAVE_V3 = 0x92b42c66840C7AD907b4BF74879FF3eF7c529473;

    address internal constant WBTC_S_TOKEN_AAVE_V3 = 0x633b207Dd676331c413D4C013a6294B0FE47cD0e;

    address internal constant WBTC_INTEREST_RATE_STRATEGY = 0x07Fa3744FeC271F80c2EA97679823F65c13CCDf4;

    address internal constant WBTC_STATA_TOKEN_AAVE_V3 = 0xbC0f50CCB8514Aa7dFEB297521c4BdEBc9C7d22d;

    address internal constant WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    uint8 internal constant WETH_DECIMALS = 18;

    address internal constant WETH_A_TOKEN_AAVE_V3 = 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8;

    address internal constant WETH_V_TOKEN_AAVE_V3 = 0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351;

    address internal constant WETH_S_TOKEN_AAVE_V3 = 0xD8Ad37849950903571df17049516a5CD4cbE55F6;

    address internal constant WETH_INTEREST_RATE_STRATEGY = 0x48AF11111764E710fcDcE2750db848C63edab57B;

    address internal constant WETH_STATA_TOKEN_AAVE_V3 = 0xb3D5Af0A52a35692D3FcbE37669b3B8C31dddE7D;

    address internal constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    uint8 internal constant USDT_DECIMALS = 6;

    address internal constant USDT_A_TOKEN_AAVE_V3 = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620;

    address internal constant USDT_V_TOKEN_AAVE_V3 = 0xfb00AC187a8Eb5AFAE4eACE434F493Eb62672df7;

    address internal constant USDT_S_TOKEN_AAVE_V3 = 0x70eFfc565DB6EEf7B927610155602d31b670e802;

    address internal constant USDT_INTEREST_RATE_STRATEGY = 0xd56eE97960b1b2953e751151Fd84888cF3F3b521;

    address internal constant USDT_STATA_TOKEN_AAVE_V3 = 0x87A1fdc4C726c459f597282be639a045062c0E46;

    address internal constant AAVE = 0xD6DF932A45C0f255f85145f286eA0b292B21C90B;

    uint8 internal constant AAVE_DECIMALS = 18;

    address internal constant AAVE_A_TOKEN_AAVE_V3 = 0xf329e36C7bF6E5E86ce2150875a84Ce77f477375;

    address internal constant AAVE_V_TOKEN_AAVE_V3 = 0xE80761Ea617F66F96274eA5e8c37f03960ecC679;

    address internal constant AAVE_S_TOKEN_AAVE_V3 = 0xfAeF6A702D15428E588d4C0614AEFb4348D83D48;

    address internal constant AAVE_INTEREST_RATE_STRATEGY = 0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

    address internal constant AAVE_STATA_TOKEN_AAVE_V3 = 0xCA2E1E33E5BCF4978E2d683656E1f5610f8C4A7E;

    uint8 internal constant WMATIC_DECIMALS = 18;

    address internal constant WMATIC_A_TOKEN_AAVE_V3 = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;

    address internal constant WMATIC_V_TOKEN_AAVE_V3 = 0x4a1c3aD6Ed28a636ee1751C69071f6be75DEb8B8;

    address internal constant WMATIC_S_TOKEN_AAVE_V3 = 0xF15F26710c827DDe8ACBA678682F3Ce24f2Fb56E;

    address internal constant WMATIC_INTEREST_RATE_STRATEGY = 0xD87974E8ED49AB16d5053ba793F4e17078Be0426;

    address internal constant WMATIC_STATA_TOKEN_AAVE_V3 = 0x98254592408E389D1dd2dBa318656C2C5c305b4E;

    address internal constant CRV = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;

    uint8 internal constant CRV_DECIMALS = 18;

    address internal constant CRV_A_TOKEN_AAVE_V3 = 0x513c7E3a9c69cA3e22550eF58AC1C0088e918FFf;

    address internal constant CRV_V_TOKEN_AAVE_V3 = 0x77CA01483f379E58174739308945f044e1a764dc;

    address internal constant CRV_S_TOKEN_AAVE_V3 = 0x08Cb71192985E936C7Cd166A8b268035e400c3c3;

    address internal constant CRV_INTEREST_RATE_STRATEGY = 0xBefcd01681224555b74eAC87207eaF9Bc3361F59;

    address internal constant CRV_STATA_TOKEN_AAVE_V3 = 0x4356941463eD4d75381AC23C9EF799B5d7C52AD8;

    address internal constant SUSHI = 0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a;

    uint8 internal constant SUSHI_DECIMALS = 18;

    address internal constant SUSHI_A_TOKEN_AAVE_V3 = 0xc45A479877e1e9Dfe9FcD4056c699575a1045dAA;

    address internal constant SUSHI_V_TOKEN_AAVE_V3 = 0x34e2eD44EF7466D5f9E0b782B5c08b57475e7907;

    address internal constant SUSHI_S_TOKEN_AAVE_V3 = 0x78246294a4c6fBf614Ed73CcC9F8b875ca8eE841;

    address internal constant SUSHI_INTEREST_RATE_STRATEGY = 0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

    address internal constant SUSHI_STATA_TOKEN_AAVE_V3 = 0xe3eDe71d32240b7EC355F0e5DD1131BBe029F934;

    address internal constant GHST = 0x385Eeac5cB85A38A9a07A70c73e0a3271CfB54A7;

    uint8 internal constant GHST_DECIMALS = 18;

    address internal constant GHST_A_TOKEN_AAVE_V3 = 0x8Eb270e296023E9D92081fdF967dDd7878724424;

    address internal constant GHST_V_TOKEN_AAVE_V3 = 0xCE186F6Cccb0c955445bb9d10C59caE488Fea559;

    address internal constant GHST_S_TOKEN_AAVE_V3 = 0x3EF10DFf4928279c004308EbADc4Db8B7620d6fc;

    address internal constant GHST_INTEREST_RATE_STRATEGY = 0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

    address internal constant GHST_STATA_TOKEN_AAVE_V3 = 0x123319636A6a9c85D9959399304F4cB23F64327e;

    address internal constant BAL = 0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3;

    uint8 internal constant BAL_DECIMALS = 18;

    address internal constant BAL_A_TOKEN_AAVE_V3 = 0x8ffDf2DE812095b1D19CB146E4c004587C0A0692;

    address internal constant BAL_V_TOKEN_AAVE_V3 = 0xA8669021776Bc142DfcA87c21b4A52595bCbB40a;

    address internal constant BAL_S_TOKEN_AAVE_V3 = 0xa5e408678469d23efDB7694b1B0A85BB0669e8bd;

    address internal constant BAL_INTEREST_RATE_STRATEGY = 0xCbDC7D7984D7AD59434f0B1999D2006898C40f9A;

    address internal constant BAL_STATA_TOKEN_AAVE_V3 = 0x1a8969FD39AbaF228e690B172C4C3Eb7c67F95E1;

    address internal constant DPI = 0x85955046DF4668e1DD369D2DE9f3AEB98DD2A369;

    uint8 internal constant DPI_DECIMALS = 18;

    address internal constant DPI_A_TOKEN_AAVE_V3 = 0x724dc807b04555b71ed48a6896b6F41593b8C637;

    address internal constant DPI_V_TOKEN_AAVE_V3 = 0xf611aEb5013fD2c0511c9CD55c7dc5C1140741A6;

    address internal constant DPI_S_TOKEN_AAVE_V3 = 0xDC1fad70953Bb3918592b6fCc374fe05F5811B6a;

    address internal constant DPI_INTEREST_RATE_STRATEGY = 0xd9d85499449f26d2A2c240defd75314f23920089;

    address internal constant DPI_STATA_TOKEN_AAVE_V3 = 0x73B788ACA5f4F0EeB3c6Da453cDf31041a77b36D;

    address internal constant EURS = 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99;

    uint8 internal constant EURS_DECIMALS = 2;

    address internal constant EURS_A_TOKEN_AAVE_V3 = 0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5;

    address internal constant EURS_V_TOKEN_AAVE_V3 = 0x5D557B07776D12967914379C71a1310e917C7555;

    address internal constant EURS_S_TOKEN_AAVE_V3 = 0x8a9FdE6925a839F6B1932d16B36aC026F8d3FbdB;

    address internal constant EURS_INTEREST_RATE_STRATEGY = 0xb96c569Ceb49440731DdD5D8c5E6DA3538f1CBF1;

    address internal constant EURS_STATA_TOKEN_AAVE_V3 = 0x02E26888Ed3240BB38f26A2adF96Af9B52b167ea;

    address internal constant jEUR = 0x4e3Decbb3645551B8A19f0eA1678079FCB33fB4c;

    uint8 internal constant jEUR_DECIMALS = 18;

    address internal constant jEUR_A_TOKEN_AAVE_V3 = 0x6533afac2E7BCCB20dca161449A13A32D391fb00;

    address internal constant jEUR_V_TOKEN_AAVE_V3 = 0x44705f578135cC5d703b4c9c122528C73Eb87145;

    address internal constant jEUR_S_TOKEN_AAVE_V3 = 0x6B4b37618D85Db2a7b469983C888040F7F05Ea3D;

    address internal constant jEUR_INTEREST_RATE_STRATEGY = 0x7448ABeD12d8538efC115af4a417e3d1367180fc;

    address internal constant jEUR_STATA_TOKEN_AAVE_V3 = 0xD992DaC78Ef3F34614E6a7d325b7b6A320FC0AB5;

    address internal constant EURA = 0xE0B52e49357Fd4DAf2c15e02058DCE6BC0057db4;

    uint8 internal constant EURA_DECIMALS = 18;

    address internal constant EURA_A_TOKEN_AAVE_V3 = 0x8437d7C167dFB82ED4Cb79CD44B7a32A1dd95c77;

    address internal constant EURA_V_TOKEN_AAVE_V3 = 0x3ca5FA07689F266e907439aFd1fBB59c44fe12f6;

    address internal constant EURA_S_TOKEN_AAVE_V3 = 0x40B4BAEcc69B882e8804f9286b12228C27F8c9BF;

    address internal constant EURA_INTEREST_RATE_STRATEGY = 0xb96c569Ceb49440731DdD5D8c5E6DA3538f1CBF1;

    address internal constant EURA_STATA_TOKEN_AAVE_V3 = 0xd3eb8796Ed36f58E03B7b4b5AD417FA74931d2c4;

    address internal constant miMATIC = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;

    uint8 internal constant miMATIC_DECIMALS = 18;

    address internal constant miMATIC_A_TOKEN_AAVE_V3 = 0xeBe517846d0F36eCEd99C735cbF6131e1fEB775D;

    address internal constant miMATIC_V_TOKEN_AAVE_V3 = 0x18248226C16BF76c032817854E7C83a2113B4f06;

    address internal constant miMATIC_S_TOKEN_AAVE_V3 = 0x687871030477bf974725232F764aa04318A8b9c8;

    address internal constant miMATIC_INTEREST_RATE_STRATEGY = 0xa8C12113DB50549A1E36FD25982C88B69A0007E0;

    address internal constant miMATIC_STATA_TOKEN_AAVE_V3 = 0x8486B49433cCed038b51d18Ae3772CDB7E31CA5e;

    address internal constant stMATIC = 0x3A58a54C066FdC0f2D55FC9C89F0415C92eBf3C4;

    uint8 internal constant stMATIC_DECIMALS = 18;

    address internal constant stMATIC_A_TOKEN_AAVE_V3 = 0xEA1132120ddcDDA2F119e99Fa7A27a0d036F7Ac9;

    address internal constant stMATIC_V_TOKEN_AAVE_V3 = 0x6b030Ff3FB9956B1B69f475B77aE0d3Cf2CC5aFa;

    address internal constant stMATIC_S_TOKEN_AAVE_V3 = 0x1fFD28689DA7d0148ff0fCB669e9f9f0Fc13a219;

    address internal constant stMATIC_INTEREST_RATE_STRATEGY = 0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

    address internal constant stMATIC_STATA_TOKEN_AAVE_V3 = 0x867A180B7060fDC27610dC9096E93534F638A315;

    address internal constant MaticX = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;

    uint8 internal constant MaticX_DECIMALS = 18;

    address internal constant MaticX_A_TOKEN_AAVE_V3 = 0x80cA0d8C38d2e2BcbaB66aA1648Bd1C7160500FE;

    address internal constant MaticX_V_TOKEN_AAVE_V3 = 0xB5b46F918C2923fC7f26DB76e8a6A6e9C4347Cf9;

    address internal constant MaticX_S_TOKEN_AAVE_V3 = 0x62fC96b27a510cF4977B59FF952Dc32378Cc221d;

    address internal constant MaticX_INTEREST_RATE_STRATEGY = 0x6B434652E4C4e3e972f9F267982F05ae0fcc24b6;

    address internal constant MaticX_STATA_TOKEN_AAVE_V3 = 0xbcDd5709641Af4BE99b1470A2B3A5203539132Ec;

    address internal constant wstETH = 0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD;

    uint8 internal constant wstETH_DECIMALS = 18;

    address internal constant wstETH_A_TOKEN_AAVE_V3 = 0xf59036CAEBeA7dC4b86638DFA2E3C97dA9FcCd40;

    address internal constant wstETH_V_TOKEN_AAVE_V3 = 0x77fA66882a8854d883101Fb8501BD3CaD347Fc32;

    address internal constant wstETH_S_TOKEN_AAVE_V3 = 0x173e54325AE58B072985DbF232436961981EA000;

    address internal constant wstETH_INTEREST_RATE_STRATEGY = 0xA6459195d60A797D278f58Ffbd2BA62Fb3F7FA1E;

    address internal constant wstETH_STATA_TOKEN_AAVE_V3 = 0x5274453F4CD5dD7280011a1Cca3B9e1b78EC59A6;

    address internal constant USDCn = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

    uint8 internal constant USDCn_DECIMALS = 6;

    address internal constant USDCn_A_TOKEN_AAVE_V3 = 0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD;

    address internal constant USDCn_V_TOKEN_AAVE_V3 = 0xE701126012EC0290822eEA17B794454d1AF8b030;

    address internal constant USDCn_S_TOKEN_AAVE_V3 = 0xc889e9f8370D14A428a9857205d99BFdB400b757;

    address internal constant USDCn_INTEREST_RATE_STRATEGY = 0xaEc90D2516c79F8Ae7165574a41EC4dF2631b36f;

    address internal constant USDCn_STATA_TOKEN_AAVE_V3 = 0x2dCa80061632f3F87c9cA28364d1d0c30cD79a19;
}
