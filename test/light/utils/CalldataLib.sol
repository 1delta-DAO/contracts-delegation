// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../contracts/1delta/modules/light/enums/DeltaEnums.sol";

library CalldataLib {
    enum SweepType {
        VALIDATE,
        BALANCE,
        AMOUNT
    }

    function transferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.TRANSFER_FROM),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function sweep(address asset, address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.SWEEP),
            asset,
            receiver,
            sweepType,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function wrap(uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.WRAP_NATIVE),
            uint112(amount) //
        ); // 14 bytes
    }

    function unwrap(address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.TRANSFERS),
            uint8(TransferIds.UNWRAP_WNATIVE),
            receiver,
            sweepType,
            uint112(amount) //
        ); // 14 bytes
    }

    function encodeFlashLoan(
        address asset,
        uint256 amount,
        address pool,
        uint8 poolType,
        uint8 poolId, //
        bytes memory data
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.FLASH_LOAN),
                uint8(poolType),
                poolId,
                asset, //
                pool,
                uint112(amount),
                uint16(data.length),
                data
            );
    }

    function morphoDepositCollateral(bytes memory market, uint assets, bytes memory data) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
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
                uint8(ComposerCommands.LENDING), // 1
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
                uint8(ComposerCommands.ERC4646), // 1
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
                uint8(ComposerCommands.ERC4646), // 1
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
                uint8(ComposerCommands.LENDING), // 1
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
                uint8(ComposerCommands.LENDING), // 1
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
                uint8(ComposerCommands.LENDING), // 1
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
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.REPAY), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function encodeAaveDeposit(address token, bool overrideAmount, uint amount, address receiver, address pool) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                uint128(amount),
                receiver,
                pool //
            );
    }

    function encodeAaveBorrow(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        uint256 mode,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                pool //
            );
    }

    function encodeAaveRepay(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                dToken,
                pool //
            );
    }

    function encodeAaveWithdraw(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address aToken,
        address pool
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                uint128(amount),
                receiver,
                aToken,
                pool //
            );
    }

    function encodeAaveV2Deposit(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                uint128(amount),
                receiver,
                pool //
            );
    }

    function encodeAaveV2Borrow(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        uint256 mode,
        address pool
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                pool //
            );
    }

    function encodeAaveV2Repay(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        uint256 mode,
        address dToken,
        address pool
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                uint128(amount),
                receiver,
                uint8(mode),
                dToken,
                pool //
            );
    }

    function encodeAaveV2Withdraw(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address aToken,
        address pool
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                uint128(amount),
                receiver,
                aToken,
                pool //
            );
    }

    function encodeCompoundV3Deposit(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address comet
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                uint128(amount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Borrow(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address comet
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                uint128(amount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Repay(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address comet
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                uint128(amount),
                receiver,
                comet //
            );
    }

    function encodeCompoundV3Withdraw(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address comet,
        bool isBase
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                uint128(amount),
                receiver,
                isBase ? uint8(1) : uint8(0),
                comet //
            );
    }



    function encodeCompoundV2Deposit(address token, bool overrideAmount, uint amount, address receiver, address cToken) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                uint128(amount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Borrow(address token, bool overrideAmount, uint amount, address receiver, address cToken) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                uint128(amount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Repay(address token, bool overrideAmount, uint amount, address receiver, address cToken) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                uint128(amount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Withdraw(address token, bool overrideAmount, uint amount, address receiver, address cToken) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                uint128(amount),
                receiver,
                cToken //
            );
    }

}
