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

    function morphoDepositCollateral(
        bytes memory market,
        uint assets,
        address receiver,
        bytes memory data, //
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.DEPOSIT), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                receiver,
                morphoB,
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function morphoDeposit(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver,
        bytes memory data,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.DEPOSIT_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares),
                receiver,
                morphoB,
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
                generateAmountBitmap(uint128(assets), false, isShares),
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
                generateAmountBitmap(uint128(assets), false, isShares),
                receiver // 20
            );
    }

    function morphoWithdraw(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.WITHDRAW_LENDING_TOKEN), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares),
                receiver, // 20
                morphoB
            );
    }

    function morphoWithdrawCollateral(
        bytes memory market, //
        uint assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.WITHDRAW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                uint128(assets), // 16
                receiver, // 20
                morphoB
            );
    }

    function morphoBorrow(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.BORROW), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares),
                receiver,
                morphoB
            );
    }

    function morphoRepay(
        bytes memory market,
        bool isShares, //
        uint assets,
        address receiver,
        bytes memory data,
        address morphoB
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING), // 1
                uint8(LenderOps.REPAY), // 1
                uint16(LenderIds.UP_TO_MORPHO), // 2
                market, // 4 * 20 + 16
                generateAmountBitmap(uint128(assets), false, isShares),
                receiver,
                morphoB,
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
                setOverrideAmount(amount, overrideAmount),
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
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
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
                setOverrideAmount(amount, overrideAmount),
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
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_AAVE_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
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
                setOverrideAmount(amount, overrideAmount),
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
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
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
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V3 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                isBase ? uint8(1) : uint8(0),
                comet //
            );
    }

    function encodeCompoundV2Deposit(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.DEPOSIT),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Borrow(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.BORROW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Repay(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.REPAY),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    function encodeCompoundV2Withdraw(
        address token,
        bool overrideAmount,
        uint amount,
        address receiver,
        address cToken
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(ComposerCommands.LENDING),
                uint8(LenderOps.WITHDRAW),
                uint16(LenderIds.UP_TO_COMPOUND_V2 - 1),
                token,
                setOverrideAmount(amount, overrideAmount),
                receiver,
                cToken //
            );
    }

    /// @dev Mask for using the injected amount
    uint256 private constant _PRE_PARAM = 1 << 127;
    /// @dev Mask for shares
    uint256 private constant _SHARES_MASK = 1 << 126;

    function generateAmountBitmap(uint128 amount, bool preParam, bool useShares) internal pure returns (uint128 am) {
        am = amount;
        if (preParam) am = uint128((am & ~_PRE_PARAM) | (1 << 127));
        if (useShares) am = uint128((am & ~_SHARES_MASK) | (1 << 126));
        return am;
    }

    function setOverrideAmount(uint256 amount, bool preParam) internal pure returns (uint128 am) {
        am = uint128(amount);
        if (preParam) am = uint128((am & ~_PRE_PARAM) | (1 << 127));
        return am;
    }
}
