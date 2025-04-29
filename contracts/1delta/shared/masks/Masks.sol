// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

abstract contract Masks {
    /// @dev Mask of lower 20 bytes.
    uint256 internal constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 1 byte.
    uint256 internal constant UINT8_MASK = 0xff;
    /// @dev Mask of lower 2 bytes.
    uint256 internal constant UINT16_MASK = 0xffff;
    /// @dev Mask of lower 3 bytes.
    uint256 internal constant UINT24_MASK = 0xffffff;
    /// @dev Mask of lower 16 bytes.
    uint256 internal constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    /// @dev Mask of lower 15 bytes.
    uint256 internal constant UINT120_MASK = 0x0000000000000000000000000000000000ffffffffffffffffffffffffffffff;
    /// @dev MIN_SQRT_RATIO + 1 from Uniswap's TickMath
    uint160 internal constant MIN_SQRT_RATIO = 4295128740;
    /// @dev MAX_SQRT_RATIO - 1 from Uniswap's TickMath
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;
    /// @dev Maximum Uint256 value
    uint256 internal constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    /// @dev Use this to distinguish FF upper bytes addresses and lower bytes addresses
    uint256 internal constant FF_ADDRESS_COMPLEMENT = 0x000000000000000000000000000000000000000000ffffffffffffffffffffff;

    /// @notice Composer-specific masks

    /// @dev The highest bit signals whether the swap is internal (the payer is this contract)
    uint256 internal constant _PAY_SELF = 1 << 255;
    /// @dev The second bit signals whether the input token is a FOT token
    ///      Only used for SWAP_EXACT_IN
    uint256 internal constant _FEE_ON_TRANSFER = 1 << 254;
    /// @dev We use uint112-encoded amounts to typically fit one bit flag, one path length (uint16)
    ///      add 2 amounts (2xuint112) into 32bytes, as such we use this mask for extracting those
    uint256 internal constant _UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;

    /// @dev Mask for using the injected amount
    uint256 internal constant _PRE_PARAM = 1 << 127;
    /// @dev Mask for shares
    uint256 internal constant _SHARES_MASK = 1 << 126;
    /// @dev Mask for morpho using unsafe repay
    uint256 internal constant _UNSAFE_AMOUNT = 1 << 125;
}
