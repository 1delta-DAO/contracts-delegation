// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
abstract contract V3ReferencesMantle {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant UNISWAP_V3_FF_FACTORY = 0xff0d922Fb1Bc191F64970ac40376643808b4B74Df90000000000000000000000;
    bytes32 internal constant UNISWAP_V3_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant FUSION_V3_FF_FACTORY = 0xff8790c2C3BA67223D83C8FCF2a5E3C650059987b40000000000000000000000;
    bytes32 internal constant FUSION_POOL_INIT_CODE_HASH = 0x1bce652aaa6528355d7a339037433a20cd28410e3967635ba8d2ddb037440dbf;

    bytes32 internal constant AGNI_V3_FF_FACTORY = 0xffe9827B4EBeB9AE41FC57efDdDd79EDddC2EA4d030000000000000000000000;
    bytes32 internal constant AGNI_POOL_INIT_CODE_HASH = 0xaf9bd540c3449b723624376f906d8d3a0e6441ff18b847f05f4f85789ab64d9a;

    bytes32 internal constant IZI_FF_FACTORY = 0xff45e5F26451CDB01B0fA1f8582E0aAD9A6F27C2180000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff9dE2dEA5c68898eb4cb2DeaFf357DFB26255a4aa0000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91;

    bytes32 internal constant BUTTER_FF_FACTORY = 0xffeeca0a86431a7b42ca2ee5f479832c3d4a4c26440000000000000000000000;
    bytes32 internal constant BUTTER_POOL_INIT_CODE_HASH = 0xc7d06444331e4f63b0764bb53c88788882395aa31961eed3c2768cc9568323ee;

    bytes32 internal constant CLEO_FF_FACTORY = 0xffAAA32926fcE6bE95ea2c51cB4Fcb60836D320C420000000000000000000000;
    bytes32 internal constant CLEO_POOL_INIT_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    bytes32 internal constant METHLAB_FF_FACTORY = 0xff8f140fc3e9211b8dc2fc1d7ee3292f6817c5dd5d0000000000000000000000;
    bytes32 internal constant METHLAB_INIT_CODE_HASH = 0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b;

    bytes32 internal constant CRUST_FF_FACTORY = 0xffEaD128BDF9Cff441eF401Ec8D18a96b4A2d252520000000000000000000000;
    bytes32 internal constant CRUST_INIT_CODE_HASH = 0x55664e1b1a13929bcf29e892daf029637225ec5c85a385091b8b31dcca255627;
}
