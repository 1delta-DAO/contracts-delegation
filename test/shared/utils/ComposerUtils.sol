// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../contracts/1delta/modules/shared/Commands.sol";

contract ComposerUtils {
    enum SweepType {
        VALIDATE,
        BALANCE,
        AMOUNT
    }

    uint8 DEFAULT_MODE = 2;
    uint256 internal constant USE_PERMIT2_FLAG = 1 << 127;
    uint256 internal constant PAY_SELF = 1 << 255;
    uint256 internal constant FOT = 1 << 254;
    uint256 internal constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    uint256 internal constant UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;
    uint256 internal constant UINT112_MASK_16 = 0x00000000000000000000000000000000ffffffffffffffffffffffffffff0000;
    uint256 internal constant UINT112_MASK_U = 0x0000ffffffffffffffffffffffffffff00000000000000000000000000000000;

    function transferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.TRANSFER_FROM),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function sweep(address asset, address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.SWEEP),
            asset,
            receiver,
            sweepType,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function wrap(uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.WRAP_NATIVE),
            uint112(amount) //
        ); // 14 bytes
    }

    function unwrap(address receiver, uint256 amount, SweepType sweepType) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.UNWRAP_WNATIVE),
            receiver,
            sweepType,
            uint112(amount) //
        ); // 14 bytes
    }

    function deposit(address asset, address receiver, uint256 amount, uint16 lenderId) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.DEPOSIT), // 1
                asset, // 20
                receiver, // 20
                populateAmountDeposit(lenderId, amount) // 15
            );
    }

    function withdraw(address asset, address receiver, uint256 amount, uint16 lenderId) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.WITHDRAW), // 1
                asset, // 20
                receiver, // 20
                populateAmountWithdraw(lenderId, amount) // 15
            );
    }

    function repay(address asset, address receiver, uint256 amount, uint16 lenderId, uint8 mode) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.REPAY), // 1
                asset, // 20
                receiver, // 20
                populateAmountRepay(lenderId, mode, amount) // 16
            );
    }

    /** MORPHO OPERATIONS */

    function morphoDepositCollateral(bytes memory market, uint assets, bytes memory data) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.MORPH), // 1
                uint8(0), // 1
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
                uint8(Commands.MORPH), // 1
                uint8(4), // 1
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
                uint8(Commands.MORPH), // 1
                uint8(5), // 1
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                receiver // 20
            );
    }

    function morphoWithdrawCollateral(bytes memory market, uint assets, address receiver) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.MORPH), // 1
                uint8(3), // 1
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
                uint8(Commands.MORPH), // 1
                uint8(1), // 1
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
                uint8(Commands.MORPH), // 1
                uint8(2), // 1
                market, // 4 * 20 + 16
                abi.encodePacked(isShares ? uint8(1) : uint8(0), uint120(assets)),
                uint16(data.length), // 2 @ 1 + 4*20
                data
            );
    }

    function borrow(address asset, address receiver, uint256 amount, uint16 lenderId, uint8 mode) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.BORROW), // 1
                asset, // 20
                receiver, // 20
                populateAmountBorrow(lenderId, mode, amount) // 16
            );
    }

    function populateAmountDeposit(uint16 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function populateAmountBorrow(uint16 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountRepay(uint16 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountWithdraw(uint16 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function encodeSwapAmountParams(uint256 amount, uint256 validate, bool paySelf, uint256 pathLength) internal pure returns (uint256) {
        uint256 am = uint16(pathLength);
        am = (am & ~UINT112_MASK_U) | (uint256(validate) << 128);
        am = (am & ~UINT112_MASK_16) | (uint256(amount) << 16);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
        return am;
    }

    function encodeSwapAmountParamsFOT(uint256 amount, uint256 validate, bool paySelf, bool fot, uint256 pathLength) internal pure returns (uint256) {
        uint256 am = uint16(pathLength);
        am = (am & ~UINT112_MASK_U) | (uint256(validate) << 128);
        am = (am & ~UINT112_MASK_16) | (uint256(amount) << 16);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
        if (fot) am = (am & ~FOT) | (1 << 254);
        return am;
    }

    function encodeFlashLoan(
        address asset,
        uint256 amount,
        uint8 poolId, //
        bytes memory data
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(Commands.FLASH_LOAN), poolId, asset, uint112(amount), uint16(data.length), data);
    }

    function encodeSwap(
        uint256 command,
        address receiver,
        uint256 amount,
        uint max,
        bool self,
        bytes memory path
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(command), receiver, encodeSwapAmountParams(amount, max, self, path.length), path);
    }

    function encodeFlashSwap(uint256 command, uint256 amount, uint max, bool self, bytes memory path) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(command), encodeSwapAmountParams(amount, max, self, path.length), path);
    }
}
