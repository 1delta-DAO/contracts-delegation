// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../contracts/1delta/modules/shared/Commands.sol";

/**
 * Lender classifier enums, expected to be encoded as uint16
 */
library LenderIds {
    uint256 internal constant UP_TO_AAVE_V3 = 1000;
    uint256 internal constant UP_TO_AAVE_V2 = 2000;
    uint256 internal constant UP_TO_COMPOUND_V3 = 3000;
    uint256 internal constant UP_TO_COMPOUND_V2 = 4000;
    uint256 internal constant UP_TO_MORPHO = 5000;
}


/**
 * Operations enums, encoded as uint8
 */
library LenderOps {
    uint256 internal constant DEPOSIT = 0;
    uint256 internal constant BORROW = 1;
    uint256 internal constant REPAY = 2;
    uint256 internal constant WITHDRAW = 3;
    uint256 internal constant DEPOSIT_LENDING_TOKEN = 4;
    uint256 internal constant WITHDRAW_LENDING_TOKEN = 5;
}

library CalldataLib {
    /** MORPHO OPERATIONS */

    function morphoDepositCollateral(bytes memory market, uint assets, bytes memory data) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.DEPOSIT), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function morphoDeposit(
        bytes memory market,
        bool isShares, //
        uint assets,
        bytes memory data
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.DEPOSIT_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function erc4646Deposit(
        address asset,
        address vault,
        bool isShares, //
        uint assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.ERC4646), // 1
                uint8(0), // 1
                asset, // 20
                vault, // 20
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)), // 16
                receiver // 20
            );
    }

    function erc4646Withdraw(
        address vault,
        bool isShares, //
        uint assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.ERC4646), // 1
                uint8(1), // 1
                vault, // 20
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)), // 16
                receiver // 20
            );
    }

    function morphoWithdraw(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.WITHDRAW_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                receiver // 20
            );
    }

    function morphoWithdrawCollateral(bytes memory market, uint assets, address receiver) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.WITHDRAW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                receiver // 20
            );
    }

    function morphoBorrow(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.BORROW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                receiver
            );
    }

    function morphoRepay(
        bytes memory market,
        bool isShares, //
        uint assets,
        bytes memory data
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.LENDING), // 1
                uint8(LenderOps.REPAY), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }
}
