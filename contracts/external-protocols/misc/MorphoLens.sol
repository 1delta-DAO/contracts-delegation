// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * Just fetching some Morpho stuff in bulk
 */
library MathLib {
    /// @dev Returns (`x` * `y`) / `d` rounded down.
    function mulDivDown(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y) / d;
    }

    /// @dev Returns (`x` * `y`) / `d` rounded up.
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        return (x * y + (d - 1)) / d;
    }
}

library SharesMathLib {
    using MathLib for uint256;

    /// @dev The number of virtual shares has been chosen low enough to prevent overflows, and high enough to ensure
    /// high precision computations.
    /// @dev Virtual shares can never be redeemed for the assets they are entitled to, but it is assumed the share price
    /// stays low enough not to inflate these assets to a significant value.
    /// @dev Warning: The assets to which virtual borrow shares are entitled behave like unrealizable bad debt.
    uint256 internal constant VIRTUAL_SHARES = 1e6;

    /// @dev A number of virtual assets of 1 enforces a conversion rate between shares and assets when a market is
    /// empty.
    uint256 internal constant VIRTUAL_ASSETS = 1;

    /// @dev Calculates the value of `assets` quoted in shares, rounding down.
    function toSharesDown(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDivDown(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding down.
    function toAssetsDown(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDivDown(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
    }

    /// @dev Calculates the value of `assets` quoted in shares, rounding up.
    function toSharesUp(uint256 assets, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return assets.mulDivUp(totalShares + VIRTUAL_SHARES, totalAssets + VIRTUAL_ASSETS);
    }

    /// @dev Calculates the value of `shares` quoted in assets, rounding up.
    function toAssetsUp(uint256 shares, uint256 totalAssets, uint256 totalShares) internal pure returns (uint256) {
        return shares.mulDivUp(totalAssets + VIRTUAL_ASSETS, totalShares + VIRTUAL_SHARES);
    }
}

interface IMorpho {
    function position(bytes32 id, address user) external view returns (uint256 supplyShares, uint128 borrowShares, uint128 collateral);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}

contract MorphoLens {
    /**
     * Get the user data if exists as packed bytes (len, data[]), data = (id,sShares,bShares,sAssets,bAssets,collateral)
     * `id` maps the data to the market in the original array
     */
    function getUserDataCompact(bytes32[] memory marketsIds, address user, address morpho) external view returns (bytes memory data) {
        uint256 totalCount;
        for (uint256 i; i < marketsIds.lenght; i++) {
            bytes32 id = marketsIds[i];
            (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = IMorpho(morpho).position(id, user);
            // no balances found - continue
            if (supplyShares == 0 && borrowShares == 0 && collateral == 0) continue;
            // balance detected allocate user balances in return data
            // increment
            totalCount++;
            (
                uint128 totalSupplyAssets,
                uint128 totalSupplyShares, //
                uint128 totalBorrowAssets,
                uint128 totalBorrowShares,
            ) = IMorpho(morpho).market(id);
            // progressively pack the data
            data = abi.encodePacked(
                data,
                uint16(i),
                supplyShares,
                borrowShares,
                SharesMathLib.toAssetsDown(supplyShares, totalSupplyAssets, totalSupplyShares),
                SharesMathLib.toAssetsUp(borrowShares, totalBorrowAssets, totalBorrowShares),
                collateral
            );
        }

        return abi.encodePacked(uint16(totalCount), data);
    }
}
