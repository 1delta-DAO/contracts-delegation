// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

abstract contract V3ReferencesArbitrum {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    bytes32 internal constant UNI_V3_FF_FACTORY = 0xff1f98431c8ad98523631ae4a59f267346ea31f9840000000000000000000000;
    bytes32 internal constant UNI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant RAMSES_FF_FACTORY = 0xffAA2cd7477c451E703f3B9Ba5663334914763edF80000000000000000000000;
    bytes32 internal constant RAMSES_POOL_INIT_CODE_HASH = 0x1565b129f2d1790f12d45301b9b084335626f0c92410bc43130763b69971135d;

    bytes32 internal constant IZI_FF_FACTORY = 0xffCFD8A067e1fa03474e79Be646c5f6b6A278473990000000000000000000000;
    bytes32 internal constant IZI_POOL_INIT_CODE_HASH = 0xbe0bfe068cdd78cafa3ddd44e214cfa4e412c15d7148e932f8043fe883865e40;

    bytes32 internal constant ALGEBRA_V3_FF_DEPLOYER = 0xff6Dd3FB9653B10e806650F107C3B5A0a6fF974F650000000000000000000000;
    bytes32 internal constant ALGEBRA_POOL_INIT_CODE_HASH = 0x6c1bebd370ba84753516bc1393c0d0a6c645856da55f5393ac8ab3d6dbc861d3;

    bytes32 internal constant SUSHI_V3_FF_DEPLOYER = 0xff1af415a1EbA07a4986a52B6f2e7dE7003D82231e0000000000000000000000;
    bytes32 internal constant SUSHI_POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    bytes32 internal constant PANCAKE_FF_FACTORY = 0xff41ff9AA7e16B8B1a8a8dc4f0eFacd93D02d071c90000000000000000000000;
    bytes32 internal constant PANCAKE_INIT_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
}
