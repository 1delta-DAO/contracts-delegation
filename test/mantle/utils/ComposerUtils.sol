// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../contracts/1delta/modules/deploy/mantle/composable/Commands.sol";

contract ComposerUtils {
    uint8 DEFAULT_MODE = 2;
    uint256 internal constant USE_PERMIT2_FLAG = 1 << 127;
    // uint256 internal constant UNWRAP_NATIVE_MASK = 1 << 254;
    // uint256 internal constant PAY_SELF = 1 << 254;
    uint256 internal constant PAY_SELF = 1 << 255;
    uint256 internal constant UINT128_MASK = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
    uint256 internal constant UINT112_MASK = 0x000000000000000000000000000000000000ffffffffffffffffffffffffffff;
    uint256 internal constant LENDER_ID_MASK = 0x0000000000000000000000000000000000ff0000000000000000000000000000;
    uint256 internal constant UINT128_MASK_UPPER = 0xffffffffffffffffffffffffffffffff00000000000000000000000000000000;

    function transferIn(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.TRANSFER_FROM),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function sweep(address asset, address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.SWEEP),
            asset,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function wrap(uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.WRAP_NATIVE),
            uint112(amount) //
        ); // 14 bytes
    }

    function unwrap(address receiver, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(Commands.UNWRAP_WNATIVE),
            receiver,
            uint112(amount) //
        ); // 14 bytes
    }

    function deposit(address asset, address receiver, uint256 amount, uint8 lenderId) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.DEPOSIT), // 1
                asset, // 20
                receiver, // 20
                populateAmountDeposit(lenderId, amount) // 15
            );
    }

    function withdraw(address asset, address receiver, uint256 amount, uint8 lenderId) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.WITHDRAW), // 1
                asset, // 20
                receiver, // 20
                populateAmountWithdraw(lenderId, amount) // 15
            );
    }

    function repay(address asset, address receiver, uint256 amount, uint8 lenderId, uint8 mode) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.REPAY), // 1
                asset, // 20
                receiver, // 20
                populateAmountRepay(lenderId, mode, amount) // 16
            );
    }

    function borrow(address asset, address receiver, uint256 amount, uint8 lenderId, uint8 mode) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(Commands.BORROW), // 1
                asset, // 20
                receiver, // 20
                populateAmountBorrow(lenderId, mode, amount) // 16
            );
    }


    function populateAmountDeposit(uint8 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function populateAmountBorrow(uint8 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountRepay(uint8 lender, uint8 mode, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, mode, uint112(amount)); // 14 + 2 byte
    }

    function populateAmountWithdraw(uint8 lender, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodePacked(lender, uint112(amount)); // 14 + 1 byte
    }

    function encodeExactOutParams(uint256 amountOut, uint256 maximumAmountIn, bool paySelf) internal pure returns (uint256) {
        uint256 am = uint128(amountOut);
        am = (am & ~UINT128_MASK_UPPER) | (uint256(maximumAmountIn) << 128);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
        return am;
    }

    function encodeExactInParams(uint256 amountIn, uint256 minimumOut, bool paySelf) internal pure returns (uint256) {
        uint256 am = uint128(amountIn);
        am = (am & ~UINT128_MASK_UPPER) | (uint256(minimumOut) << 128);
        if (paySelf) am = (am & ~PAY_SELF) | (1 << 255);
        return am;
    }

    function encodeSwap(
        uint256 command,
        address receiver,
        uint256 amount,
        uint max,
        bool self,
        bytes memory path
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                uint8(command),
                encodeExactInParams(amount, max, self),
                receiver,
                uint16(path.length), // begin agni data
                path
            );
    }
}
