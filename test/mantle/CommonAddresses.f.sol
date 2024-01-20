// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract AddressesMantle {
    address internal WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address internal WBTC = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    address internal WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address internal USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address internal USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address internal axlFRAX = 0x406Cde76a3fD20e48bc1E0F60651e60Ae204B040;
    address internal axlUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address internal USDY = address(0);
    address internal mUSD = address(0);

    address veloFactory = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;


    address veloRouter = 0xCe30506F6c1Cea34aC704f93d51d55058791E497;

    bytes32 internal constant VELO_FF_FACTORY = 0xff99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C0000000000000000000000;
    bytes32 constant VELO_CODE_HASH = 0x0ccd005ee58d5fb11632ef5c2e0866256b240965c62c8e990c0f84a97f311879;
    address internal constant VELO_FACOTRY = 0x99F9a4A96549342546f9DAE5B2738EDDcD43Bf4C;
    
    bytes32 internal constant FUSION_V2_FF_FACTORY = 0xffE5020961fA51ffd3662CDf307dEf18F9a87Cce7c0000000000000000000000;
    bytes32 internal constant CODE_HASH_FUSION_V2 = 0x58c684aeb03fe49c8a3080db88e425fae262c5ef5bf0e8acffc0526c6e3c03a0;

    address internal constant MERCHANT_MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;

    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of upper 20 bytes.
    uint256 internal constant ADDRESS_MASK_UPPER = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;
}
