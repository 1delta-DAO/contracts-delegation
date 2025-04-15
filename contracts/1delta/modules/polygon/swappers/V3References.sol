// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * @title Uniswap V3 type swapper contract
 * @notice Executes Cl swaps and pushing data to the callbacks
 */
abstract contract V3ReferencesPolygon {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant SMARDEX_FF_FACTORY = 0xff9A1e1681f6D59Ca051776410465AfAda6384398f0000000000000000000000;
    bytes32 internal constant CODE_HASH_SMARDEX = 0x33bee911475f015247aeb1eebe149d1c6d2669be54126c29d85df6b0abb4c4e9;

    bytes32 internal constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 internal constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant RETRO_FF_FACTORY = 0xff91e1B99072f238352f59e58de875691e20Dc19c10000000000000000000000;
    bytes32 internal constant RETRO_POOL_INIT_CODE_HASH = 0x817e07951f93017a93327ac8cc31e946540203a19e1ecc37bc1761965c2d1090;

    bytes32 internal constant IZI_FF_FACTORY = 0xffcA7e21764CD8f7c1Ec40e651E25Da68AeD0960370000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff2d98e2fa9da15aa6dc9581ab097ced7af697cb920000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    bytes32 internal constant SUSHI_V3_FF_DEPLOYER = 0xff917933899c6a5F8E37F31E19f92CdBFF7e8FF0e20000000000000000000000;
    bytes32 internal constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
}
