// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import {IComet} from "../1delta/interfaces/IComet.sol";

contract CometLens {
    struct AssetData {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
        // additional
        bool isBase;
        uint256 price;
        int256 reserves;
        // base only
        uint256 borrowRate;
        uint256 supplyRate;
        uint256 utilization;
        int256 baseReserves;
        // totals collateral
        uint128 totalSupplyAsset;
        uint256 totalBorrow;
        // only base asset
        uint256 totalSupply;
        // totals basic
        // // 1st slot
        // uint64 baseSupplyIndex;
        // uint64 baseBorrowIndex;
        // uint64 trackingSupplyIndex;
        // uint64 trackingBorrowIndex;
        // // 2nd slot
        // uint104 totalSupplyBase;
        // uint104 totalBorrowBase;
        // uint40 lastAccrualTime;
        // uint8 pauseFlags;
    }

    function getAssetData(address asset, address comet) external view returns (AssetData memory data) {
        address base = IComet(comet).baseToken();
        bool isBase = asset == base;
        data.isBase = isBase;
        IComet.TotalsCollateral memory totals = IComet(comet).totalsCollateral(asset);
        data.totalSupplyAsset = totals.totalSupplyAsset;
        data.reserves = int256(IComet(comet).getCollateralReserves(asset));
        if (isBase) {
            uint256 utilization = IComet(comet).getUtilization();
            data.utilization = utilization;
            data.supplyRate = IComet(comet).getSupplyRate(utilization);
            data.borrowRate = IComet(comet).getBorrowRate(utilization);
            data.baseReserves = IComet(comet).getReserves();
            data.totalBorrow = IComet(comet).totalBorrow();
            data.totalSupply = IComet(comet).totalSupply();
        } else {
            IComet.AssetInfo memory assetInfo = IComet(comet).getAssetInfoByAddress(asset);
            data.price = IComet(comet).getPrice(assetInfo.priceFeed);
            data.offset = assetInfo.offset;
            data.asset = assetInfo.asset;
            data.priceFeed = assetInfo.priceFeed;
            data.scale = assetInfo.scale;
            data.borrowCollateralFactor = assetInfo.borrowCollateralFactor;
            data.liquidateCollateralFactor = assetInfo.liquidateCollateralFactor;
            data.liquidationFactor = assetInfo.liquidationFactor;
            data.supplyCap = assetInfo.supplyCap;
        }
    }

    struct UserData {
        bool isAllowed;
        uint256 borrowBalance;
        uint256 supplyBalance;
        // user basic
        int104 principal;
        uint64 baseTrackingIndex;
        uint64 baseTrackingAccrued;
        uint16 assetsIn;
        // user collateral
        uint128 balance;
    }

    function getUserData(
        address user,
        address asset,
        address comet,
        address delta
    ) external view returns (UserData memory data) {
        address base = IComet(comet).baseToken();
        bool isBase = asset == base;
        data.isAllowed = IComet(comet).isAllowed(user, delta);
        IComet.UserBasic memory userBasic = IComet(comet).userBasic(user);
        data.principal = userBasic.principal;
        data.baseTrackingIndex = userBasic.baseTrackingIndex;
        data.baseTrackingAccrued = userBasic.baseTrackingAccrued;
        data.assetsIn = userBasic.assetsIn;
        IComet.UserCollateral memory userCollateral = IComet(comet).userCollateral(user, asset);
        data.balance = userCollateral.balance;
        if (isBase) {
            data.supplyBalance = IComet(comet).balanceOf(user);
            data.borrowBalance = IComet(comet).borrowBalanceOf(user);
        }
    }
}
