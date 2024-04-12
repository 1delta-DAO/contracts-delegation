// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesMantle {
    // assets

    address internal WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address internal WBTC = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    address internal WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address internal CLEO = 0xC1E0C8C30F251A07a894609616580ad2CEb547F2;
    address internal USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address internal USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address internal METH = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0;

    address internal axlFRAX = 0x406Cde76a3fD20e48bc1E0F60651e60Ae204B040;
    address internal axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address internal USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;
    address internal mUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;
    address internal USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal PUFF = 0x26a6b0dcdCfb981362aFA56D581e4A7dBA3Be140;

    // users
    address internal testUser = 0xaaaa4a3F69b6DB76889bDfa4edBe1c0BB57BAA5c;

    address internal CLEO_WMNT_POOL = 0x762B916297235dc920a8c684419e41Ab0099A242;

    address veloFactory = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    address veloRouter = 0xCe30506F6c1Cea34aC704f93d51d55058791E497;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACOTRY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;
    address internal constant CLEO_V1_FACOTRY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;

    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    address internal constant AURELIUS_POOL = 0x7c9C6F5BEd9Cfe5B9070C7D3322CF39eAD2F9492;
    address internal constant LENDLE_POOL = 0xCFa5aE7c2CE8Fadc6426C1ff872cA45378Fb7cF3;

    address internal constant AURELIUS_A_USDT = 0x893DA3225a2FCF13cCA674d1A1bb5a2eA1F3DD14;
    address internal constant AURELIUS_A_USDC = 0x833b5C0379A597351c6Cd3eFE246534bf3aE5f9F;
    address internal constant AURELIUS_A_WETH = 0xc3B515BCa486520483EF182c3128F72ce270C069;
    address internal constant AURELIUS_A_WMNT = 0x067DDc903148968d49AbC3144fd7619820F16949;
    address internal constant AURELIUS_A_WBTC = 0xF91798762cc61971df6Df0e15F0904e174387477;
    address internal constant AURELIUS_A_METH = 0xBb406187C01cC1c9EAf9d4b5C924b7FA37aeCEFD;

    address internal constant AURELIUS_V_USDT = 0xc799FE29b67599010A55Ec14a8031aF2a2521470;
    address internal constant AURELIUS_V_USDC = 0xaA9c890CA3E6B163487dE3C11847B50e48230b45;
    address internal constant AURELIUS_V_WETH = 0x45cccE9bC8e883ef7805Ea73B88D5D528C7CEc55;
    address internal constant AURELIUS_V_WMNT = 0x4C3c0650DdCB767D71c91fA89ee9e5a2CD335834;
    address internal constant AURELIUS_V_WBTC = 0xd632fd1D737c6Db356D747D09642Bef8Ae453f4D;
    address internal constant AURELIUS_V_METH = 0x00dFD5F920CCf08eB0581D605BAb413d289c21b4;

    address internal constant AURELIUS_S_USDT = 0x61627C3E37A4e57A4Edb5cd52Ce8221d9C5bDA3d;
    address internal constant AURELIUS_S_USDC = 0xB41Cf1EEAdfD17FBc0086E9e856f1ac5460064d2;
    address internal constant AURELIUS_S_WETH = 0xFbacE7bf40Dd1B9158236a23e96C11eBD03a2D42;
    address internal constant AURELIUS_S_WMNT = 0x6110868e963F8Badf4D79Bc79C8Ac1e13cd59735;
    address internal constant AURELIUS_S_WBTC = 0xBc9B223D335c624f55C8b3a70f883FfEFB890A0E;
    address internal constant AURELIUS_S_METH = 0x2D422c5EaD5fA3c26aeC97D070343353e2086A1d;

    address internal constant LENDLE_A_USDT = 0xE71cbaaa6B093FcE66211E6f218780685077D8B5;
    address internal constant LENDLE_A_USDC = 0xF36AFb467D1f05541d998BBBcd5F7167D67bd8fC;
    address internal constant LENDLE_A_WETH = 0x787Cb0D29194f0fAcA73884C383CF4d2501bb874;
    address internal constant LENDLE_A_WMNT = 0x683696523512636B46A826A7e3D1B0658E8e2e1c;
    address internal constant LENDLE_A_WBTC = 0x44CCCBbD7A5A9e2202076ea80C185DA0058f1715;
    address internal constant LENDLE_A_METH = 0x0e927Aa52A38783C1Fd5DfA5c8873cbdBd01D2Ca;

    address internal constant LENDLE_V_USDT = 0xaC3c14071c80819113DF501E1AB767be910d5e5a;
    address internal constant LENDLE_V_USDC = 0x334a542b51212b8Bcd6F96EfD718D55A9b7D1c35;
    address internal constant LENDLE_V_WETH = 0x5DF9a4BE4F9D717b2bFEce9eC350DcF4cbCb91d8;
    address internal constant LENDLE_V_WMNT = 0x18d3E4F9951fedcdDD806538857eBED2F5F423B7;
    address internal constant LENDLE_V_WBTC = 0x42f9F9202D5F4412148662Cf3bC68D704c8E354f;
    address internal constant LENDLE_V_METH = 0xd739fB7a3b652306d00F92b20439aFC637650254;

    address internal constant LENDLE_S_USDT = 0xEA8BD20f6c5424Ab4acf132c70b6C7355e11F62e;
    address internal constant LENDLE_S_USDC = 0xEe8D412A4EF6613c08889f9CD1Fd7D4a065f9A8B;
    address internal constant LENDLE_S_WETH = 0x0cA5e3CD5f3273B066422291edDa3768451FbB68;
    address internal constant LENDLE_S_WMNT = 0xafefc53Be7e32C7510f054Abb1ec5E44C03fCCaB;
    address internal constant LENDLE_S_WBTC = 0x1817Cde5CD6423C3b87039e1CB000BB2aC4E05c7;
    address internal constant LENDLE_S_METH = 0x614110493CEAe1171532eB635242E4ca71CcBBa2;

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;

    /** DEFAULTS */

    uint8 DEFAULT_LENDER = 0;

    /** DEX CONFIG */

    uint24 internal DEX_FEE_STABLES = 100;
    uint24 internal DEX_FEE_LOW_MEDIUM = 2500;
    uint24 internal DEX_FEE_LOW_HIGH = 3000;
    uint24 internal DEX_FEE_LOW = 500;
    uint24 internal DEX_FEE_NONE = 0;
    uint24 internal BIN_STEP_LOWEST = 1;

    uint8 internal AGNI = 1;
    uint8 internal FUSION_X = 0;
    uint8 internal BUTTER = 3;
    uint8 internal CLEOPATRA_CL = 4;
    uint8 internal IZUMI = 100;

    uint8 internal FUSION_X_V2 = 50;
    uint8 internal MERCHANT_MOE = 51;
    uint8 internal MERCHANT_MOE_LB = 103;
    uint8 internal KTX = 104;

    /** TRADE TYPE FLAG GETTERS */

    function getOpenExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (6, 0, 2);
    }

    function getOpenExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 1, 2);
    }

    function getCollateralSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (6, 0, 3);
    }

    function getCollateralSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (3, 1, 3);
    }

    function getCloseExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (8, 0, 3);
    }

    function getCloseExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (5, 1, 3);
    }

    function getDebtSwapExactInFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (8, 0, 2);
    }

    function getDebtSwapExactOutFlags() internal pure returns (uint8 flagStart, uint8 flagMiddle, uint8 flagEnd) {
        return (5, 1, 2);
    }

    /** we can use a pair struct to identify a functional path */
    struct Pair {
        address token0;
        address token1;
        uint24 fee;
        uint8 dex;
    }

    /** HELPER FUNCTIONS */

    /** OPEN */

    function getOpenExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getOpenExactOutSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getOpenExactInMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = IZUMI;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_STABLES;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getOpenExactOutMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = FUSION_X;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_LOW;
        poolId = IZUMI;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCloseExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseExactInMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = IZUMI;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_STABLES;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getCloseExactOutMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = FUSION_X;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_LOW;
        poolId = IZUMI;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCollateralSwapExactOutSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCollateralSwapExactInMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = AGNI;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, WETH);
        fee = DEX_FEE_LOW;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getCollateralSwapExactOutMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW_MEDIUM;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = AGNI;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, WETH);
        fee = DEX_FEE_LOW;
        poolId = FUSION_X;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getDebtSwapExactOutSingle(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW_MEDIUM;
        uint8 poolId = AGNI;
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getDebtSwapExactInMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = BUTTER;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_LOW;
        poolId = BUTTER;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getDebtSwapExactOutMulti(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_LOW;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = BUTTER;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_LOW;
        poolId = BUTTER;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

       /** OPEN */

    function getOpenExactInSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getOpenExactOutSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getOpenExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getOpenExactInMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getOpenExactOutMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getOpenExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** CLOSE */

    function getCloseExactOutSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getCloseExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCloseExactInSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getCloseExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCloseExactInMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, USDT);
        fee = DEX_FEE_STABLES;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getCloseExactOutMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_STABLES;
        (uint8 actionId, uint8 midId, uint8 endId) = getCloseExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, USDT);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** COLLATERAL SWAP */

    function getCollateralSwapExactInSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getCollateralSwapExactOutSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getCollateralSwapExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getCollateralSwapExactInMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, METH);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getCollateralSwapExactOutMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getCollateralSwapExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, METH);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }

    /** DEBT SWAP */

    function getDebtSwapExactInSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getDebtSwapExactInFlags();
        return abi.encodePacked(tokenIn, fee, poolId, actionId, tokenOut, endId);
    }

    function getDebtSwapExactOutSingleV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        uint8 poolId = MERCHANT_MOE;
        (uint8 actionId, , uint8 endId) = getDebtSwapExactOutFlags();
        return abi.encodePacked(tokenOut, fee, poolId, actionId, tokenIn, endId);
    }

    function getDebtSwapExactInMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactInFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenIn, fee, poolId, actionId, METH);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenOut, endId);
    }

    function getDebtSwapExactOutMultiV2(address tokenIn, address tokenOut) internal view returns (bytes memory data) {
        uint24 fee = DEX_FEE_NONE;
        (uint8 actionId, uint8 midId, uint8 endId) = getDebtSwapExactOutFlags();
        uint8 poolId = MERCHANT_MOE;
        bytes memory firstPart = abi.encodePacked(tokenOut, fee, poolId, actionId, METH);
        fee = DEX_FEE_NONE;
        poolId = MERCHANT_MOE;
        return abi.encodePacked(firstPart, fee, poolId, midId, tokenIn, endId);
    }
}
