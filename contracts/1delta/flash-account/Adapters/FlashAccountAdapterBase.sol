// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
abstract contract FlashAccountAdapterBase {
    address public constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    mapping(address => mapping(address => bool)) isApprovedAddress;

    receive() external payable virtual {}

    function _transferERC20(address token, address receiver, uint256 amount) internal {
        if (amount > 0) {
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
        }
    }

    function _transferFromERC20(address token, address from, address receiver, uint256 amount) internal {
        if (amount > 0) {
            SafeERC20.safeTransferFrom(IERC20(token), from, receiver, amount);
        }
    }

    function _transferNative(address receiver, uint256 amount) internal {
        if (amount > 0 && address(this).balance >= amount) {
            (bool success, bytes memory returndata) = receiver.call{value: amount}("");
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    function _getERC20Balance(address token, address account) internal view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}
