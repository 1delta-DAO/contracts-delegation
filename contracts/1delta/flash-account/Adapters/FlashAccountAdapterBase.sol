// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
abstract contract FlashAccountAdapterBase {
    error ArrayLengthMismatch();

    address public constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    mapping(address => mapping(address => bool)) public isApprovedAddress;

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

    /**
     * @notice Execute multiple function calls in a single transaction
     * @dev If a call fails, the entire transaction reverts
     * @param targets Array of contract addresses to call
     * @param values Optional array of native token amounts to send with each call
     * @param data Array of calldata to send to each target
     * @return results Array of return data from each call
     */
    function multicall(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata data
    ) external payable virtual returns (bytes[] memory results) {
        // check array length
        if (targets.length != data.length) revert ArrayLengthMismatch();

        // if values array is provided, check if its length matches the targets array
        if (values.length > 0 && targets.length != values.length) revert ArrayLengthMismatch();

        results = new bytes[](targets.length);

        bool success;
        bytes memory result;
        for (uint256 i = 0; i < targets.length; i++) {
            if (values.length > 0 && values[i] > 0) {
                (success, result) = targets[i].call{value: values[i]}(data[i]);
            } else {
                (success, result) = targets[i].call(data[i]);
            }

            if (!success) {
                // revert with the result as revert reason
                assembly ("memory-safe") {
                    revert(add(result, 32), mload(result))
                }
            }

            results[i] = result;
        }

        return results;
    }
}
