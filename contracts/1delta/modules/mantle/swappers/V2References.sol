// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

abstract contract V2ReferencesMantle {
    ////////////////////////////////////////////////////
    // dex references
    ////////////////////////////////////////////////////

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    bytes32 internal constant TROPICAL_SWAP_FF_FACTORY = 0xff5b54d3610ec3f7fb1d5b42ccf4df0fb4e136f2490000000000000000000000;
    bytes32 internal constant CODE_HASH_TROPICAL_SWAP = 0x321aea434584ceee22f77514cbdc4c631d3feba4b643c492f852c922a409ed1e;

    bytes32 internal constant MANTLESWAP_FF_FACTORY = 0xff5c84e5d27fc7575d002fe98c5a1791ac3ce6fd2f0000000000000000000000;
    bytes32 internal constant CODE_HASH_MANTLESWAP = 0x248aa3d53dff9c2e464d6feb0fae0ee52adebff933dd9c2ee6744356b46cf848;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACTORY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;

    bytes32 internal constant CLEO_V1_FF_FACTORY = 0xffAAA16c016BF556fcD620328f0759252E29b1AB570000000000000000000000;
    bytes32 constant CLEO_V1_CODE_HASH = 0xbf2404274de2b11f05e5aebd49e508de933034cb5fa2d0ac3de8cbd4bcef47dc;

    bytes32 internal constant STRATUM_FF_FACTORY = 0xff061FFE84B0F9E1669A6bf24548E5390DBf1e03b20000000000000000000000;
    bytes32 constant STRATUM_CODE_HASH = 0xeb675862e19b0846fd47f7db0e8f2bf8f8da0dcd0c9aa75603248566f3faa805;

    bytes32 internal constant CRUST_V1_FF_FACTORY = 0xff62DbCa39067f99C9D788a253cB325c6BA50e51cE0000000000000000000000;
    bytes32 constant CRUST_V1_CODE_HASH = 0x7bc86d3461c6b25a75205e3bcd8e9815e8477f2af410ccbe931d784a528143fd;
}
