// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

abstract contract V3ReferencesTaiko {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant IZI_FF_FACTORY = 0xff8c7d3063579BdB0b90997e18A770eaE32E1eBb080000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    // henjin
    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff0d22b434E478386Cd3564956BFc722073B3508f60000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf;

    // SwapSicle
    bytes32 internal constant ALGEBRA_V3_SS_FF_DEPLOYER = 0xffb68b27a1c93A52d698EecA5a759E2E4469432C090000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_SS_INIT_CODE_HASH = 0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d;

    bytes32 internal constant DTX_FF_FACTORY = 0xfffCA1AEf282A99390B62Ca8416a68F5747716260c0000000000000000000000;
    bytes32 internal constant DTX_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant UNISWAP_V3_FF_FACTORY = 0xff75FC67473A91335B5b8F8821277262a13B38c9b30000000000000000000000;
    bytes32 internal constant UNISWAP_V3_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant PANKO_FF_FACTORY = 0xff7DD105453D0AEf177743F5461d7472cC779e63f70000000000000000000000;
    bytes32 internal constant PANKO_INIT_CODE_HASH = 0x72390f3f9e3d8044b0b3a9836ba01a85bb91416ad47a08360a78788e9602bd5e;
}
