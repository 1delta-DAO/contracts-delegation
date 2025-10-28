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

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address loanToken, address collateralToken, address oracle, address irm, uint256 lltv);
}

interface IAdaptiveCurveIrm {
    /// @notice Rate at target utilization.
    /// @dev Tells the height of the curve.
    function rateAtTarget(bytes32 id) external view returns (int256);
}

interface IOracle {
    /// @notice Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.
    /// @dev It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
    /// 10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
    /// decimals of precision.
    function price() external view returns (uint256);
}

interface IMoolahOracle {
    function peek(address asset) external view returns (uint256);
}

interface IMoolah {
    /// @notice Returns `true` if `account` is whitelisted of market `id`.
    function isWhiteList(bytes32 id, address account) external view returns (bool);
    /// @notice get the provider for the market.
    function providers(bytes32 id, address token) external view returns (address);
}

contract MorphoLens {
    /**
     * Get the user data if exists as packed bytes (len, data[]), data = (id,sShares,bShares,sAssets,bAssets,collateral)
     * `id` maps the data to the market in the original array
     */
    function getUserDataCompact(bytes32[] calldata marketsIds, address user, address morpho) external view returns (bytes memory data) {
        uint256 totalCount;
        for (uint256 i; i < marketsIds.length; i++) {
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
                uint128 totalBorrowShares,,
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

    /**
     * get markets data as compressed bytes array of full morpho markets, the layout for a market is:
     *  loanToken:              20b
     *  collateralToken:        20b
     *  oracle:                 20b
     *  irm:                    20b
     *  lltv:                   16b
     *  price:                  32b
     *  rateAtTarget:           32b
     *  totalSupplyAssets:      16b
     *  totalSupplyShares:      16b
     *  totalBorrowAssets:      16b
     *  totalBorrowShares:      16b
     *  lastUpdate:             16b
     *  fee:                    16b
     * As this is a determinisitic element size, the array is implicitly indexed
     */
    function getMarketDataCompact(address morpho, bytes32[] calldata marketsIds) external view returns (bytes memory data) {
        // each entry makes 4*20 (addressses) + 16 (lltv) + 32 (price) + 32 (rateAtTarget) + 96 bytes (market) (=256) in size
        // the return data is therfore implicitly indexed
        for (uint256 i; i < marketsIds.length; i++) {
            bytes32 id = marketsIds[i];
            // pack market supply statuses
            bytes memory market = getPackedMarket(morpho, id);
            // get metadata
            (
                address loanToken,
                address collateralToken, //
                address oracle,
                address irm,
                uint256 lltv
            ) = IMorpho(morpho).idToMarketParams(id);

            // get price from oracle
            uint256 price;
            if (oracle != address(0)) {
                try IOracle(oracle).price() returns (uint256 _price) {
                    price = _price;
                } catch {}
            }
            // get rate
            uint256 rateAtTarget;
            if (irm != address(0)) {
                try IAdaptiveCurveIrm(irm).rateAtTarget(id) returns (int256 _rateAtTarget) {
                    rateAtTarget = uint256(_rateAtTarget);
                } catch {}
            }

            // progressively pack the data
            data = abi.encodePacked(data, loanToken, collateralToken, oracle, irm, uint128(lltv), price, rateAtTarget, market);
        }

        return data;
    }

    /// @notice use to get the market data for Moolah protocol
    function getMoolahMarketDataCompact(address morpho, bytes32[] calldata marketsIds) external view returns (bytes memory data) {
        // each entry makes 4*20 (addresses) + 16 (lltv) + 32 (loanPrice) + 32 (collateralPrice) + 32 (rateAtTarget)
        // + 96 bytes (market) + 1 byte (hasWhitelist) + 1 byte (hasProvider)(=290) in size. The return data is therfore implicitly indexed
        for (uint256 i; i < marketsIds.length; i++) {
            bytes32 id = marketsIds[i];
            // pack market supply statuses
            bytes memory market = getPackedMarket(morpho, id);
            // get metadata
            (
                address loanToken,
                address collateralToken, //
                address oracle,
                address irm,
                uint256 lltv
            ) = IMorpho(morpho).idToMarketParams(id);

            // get prices from moolah oracle for both loan and collateral tokens
            bytes memory temp;
            if (oracle != address(0)) {
                try IMoolahOracle(oracle).peek(loanToken) returns (uint256 _loanPrice) {
                    temp = abi.encodePacked(_loanPrice);
                } catch {
                    temp = abi.encodePacked(uint256(0));
                }
                try IMoolahOracle(oracle).peek(collateralToken) returns (uint256 _collateralPrice) {
                    temp = abi.encodePacked(temp, _collateralPrice);
                } catch {
                    temp = abi.encodePacked(temp, uint256(0));
                }
            }
            // encode rate and market
            if (irm != address(0)) {
                try IAdaptiveCurveIrm(irm).rateAtTarget(id) returns (int256 _rateAtTarget) {
                    temp = abi.encodePacked(temp, uint256(_rateAtTarget), market);
                } catch {
                    temp = abi.encodePacked(temp, uint256(0), market);
                }
            }
            // encode hasWhitelist
            if (irm != address(0)) {
                try IMoolah(morpho).isWhiteList(id, 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045) returns (bool _isWhitelisted) {
                    temp = abi.encodePacked(temp, !_isWhitelisted);
                } catch {
                    temp = abi.encodePacked(temp, bytes1(0));
                }
            }
            // encode hasProvider
            try IMoolah(morpho).providers(id, collateralToken) returns (address provider) {
                temp = abi.encodePacked(temp, provider != address(0));
            } catch {
                temp = abi.encodePacked(temp, bytes1(0));
            }

            // progressively pack the data
            data = abi.encodePacked(data, loanToken, collateralToken, oracle, irm, uint128(lltv), temp);
        }

        return data;
    }

    /**
     * Get market as 96 bytes array
     */
    function getPackedMarket(address morpho, bytes32 id) private view returns (bytes memory data) {
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee //
        ) = IMorpho(morpho).market(id);
        // tightly pack the data
        data = abi.encodePacked(totalSupplyAssets, totalSupplyShares, totalBorrowAssets, totalBorrowShares, lastUpdate, fee);
    }
}
