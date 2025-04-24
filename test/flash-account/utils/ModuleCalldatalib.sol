// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashAccountErc7579} from "contracts/1delta/flash-account/FlashAccountErc7579.sol";
import "contracts/1delta/flash-account/utils/ModeLib.sol";

library FlashLoanLib {
    /// @notice Creates the full flash loan execution including user operation data
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param flashLoanProvider The flash loan provider address
    /// @param flashLoanCalldata The specific provider's flash loan calldata
    /// @return executeCalldata The encoded execute calldata ready for user operation
    function createFlashLoanExecute(
        address moduleAddress,
        address flashLoanProvider,
        bytes memory flashLoanCalldata
    )
        internal
        pure
        returns (bytes memory executeCalldata)
    {
        bytes memory flashloanCallData = abi.encodeWithSelector(FlashAccountErc7579.flashLoan.selector, flashLoanProvider, flashLoanCalldata);

        return abi.encodeWithSignature(
            "execute(bytes32,bytes)", ModeLib.encodeSimpleSingle(), abi.encodePacked(moduleAddress, uint256(0), flashloanCallData)
        );
    }

    /// @notice Creates Aave V3 simple flash loan calldata
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param token The token to borrow
    /// @param amount The amount to borrow
    /// @param data The data to execute after the flash loan
    /// @return aaveV3FlashLoanCalldata The encoded Aave V3 flash loan calldata
    function createAaveV3SimpleFlashLoanCalldata(
        address moduleAddress,
        address token,
        uint256 amount,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory aaveV3FlashLoanCalldata)
    {
        return abi.encodeWithSelector(
            0x42b0b77c, // flashLoanSimple selector
            moduleAddress,
            token,
            amount,
            abi.encode(ModeLib.encodeSimpleBatch(), data),
            0
        );
    }

    /// @notice Creates Aave V2/V3 flash loan calldata
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param assets The tokens to borrow
    /// @param amounts The amounts to borrow
    /// @param data The data to execute after the flash loan
    /// @return aaveV2FlashLoanCalldata The encoded Aave V2/V3 flash loan calldata
    function createAaveFlashLoanCalldata(
        address moduleAddress,
        address[] memory assets,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory aaveV2FlashLoanCalldata)
    {
        uint256[] memory modes = new uint256[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0; // no debt
        }

        return abi.encodeWithSelector(
            0xab9c4b5d, // flashLoan.selector
            moduleAddress,
            assets,
            amounts,
            modes,
            moduleAddress,
            abi.encode(ModeLib.encodeSimpleBatch(), data),
            0
        );
    }

    /// @notice Creates Balancer V2 flash loan calldata
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param tokens The tokens to borrow
    /// @param amounts The amounts to borrow
    /// @param data The data to execute after the flash loan
    /// @return balancerV2FlashLoanCalldata The encoded Balancer V2 flash loan calldata
    function createBalancerV2FlashLoanCalldata(
        address moduleAddress,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory balancerV2FlashLoanCalldata)
    {
        return abi.encodeWithSelector(
            0x5c38449e, // balancer flashloan selector
            moduleAddress,
            tokens,
            amounts,
            abi.encode(ModeLib.encodeSimpleBatch(), data)
        );
    }

    /// @notice Creates Balancer V2 simple flash loan calldata
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param token The token to borrow
    /// @param amount The amount to borrow
    /// @param data The data to execute after the flash loan
    /// @return balancerV2FlashLoanCalldata The encoded Balancer V2 simple flash loan calldata
    function createBalancerV2SimpleFlashLoanCalldata(
        address moduleAddress,
        address token,
        uint256 amount,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory balancerV2FlashLoanCalldata)
    {
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        return createBalancerV2FlashLoanCalldata(moduleAddress, tokens, amounts, data);
    }

    /// @notice Creates Balancer V3 flash loan calldata
    /// @param moduleAddress The FlashAccountErc7579 module address
    /// @param token The token to borrow
    /// @param amount The amount to borrow
    /// @param data The data to execute after the flash loan
    /// @return balancerV3FlashLoanCalldata The encoded Balancer V3 flash loan calldata
    function createBalancerV3FlashLoanCalldata(
        address moduleAddress,
        address token,
        uint256 amount,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "unlock(bytes)",
            abi.encodeWithSignature("receiveFlashLoan(bytes)", abi.encodePacked(token, amount, abi.encode(ModeLib.encodeSimpleBatch(), data)))
        );
    }

    /// @notice Creates Morpho flash loan calldata
    /// @param token The token to borrow
    /// @param amount The amount to borrow
    /// @param data The data to execute after the flash loan
    /// @return morphoFlashLoanCalldata The encoded Morpho flash loan calldata
    function createMorphoFlashLoanCalldata(
        address token,
        uint256 amount,
        bytes memory data
    )
        internal
        pure
        returns (bytes memory morphoFlashLoanCalldata)
    {
        return abi.encodeWithSelector(
            0xe0232b42, // "flashLoan(address,uint256,bytes)"
            token,
            amount,
            abi.encodePacked(
                token, // used for repaying the flash loan
                abi.encode(ModeLib.encodeSimpleBatch(), data)
            )
        );
    }
}

struct Execution {
    /// @notice The target address for the transaction
    address target;
    /// @notice The value in wei to send with the transaction
    uint256 value;
    /// @notice The calldata for the transaction
    bytes callData;
}

library ExecLib {
    function get2771CallData(bytes calldata) internal view returns (bytes memory callData) {
        /// @solidity memory-safe-assembly
        assembly {
            // as per solidity docs
            function allocate(length) -> pos {
                pos := mload(0x40)
                mstore(0x40, add(pos, length))
            }

            callData := allocate(add(calldatasize(), 0x20)) //allocate extra 0x20 to store length
            mstore(callData, add(calldatasize(), 0x14)) //store length, extra 0x14 is for msg.sender address
            calldatacopy(add(callData, 0x20), 0, calldatasize())

            // The msg.sender address is shifted to the left by 12 bytes to remove the padding
            // Then the address without padding is stored right after the calldata
            let senderPtr := allocate(0x14)
            mstore(senderPtr, shl(96, caller()))
        }
    }

    function decodeBatch(bytes calldata callData) internal pure returns (Execution[] calldata executionBatch) {
        /*
         * Batch Call Calldata Layout
         * Offset (in bytes)    | Length (in bytes) | Contents
         * 0x0                  | 0x4               | bytes4 function selector
         * 0x4                  | -                 |
        abi.encode(IERC7579Execution.Execution[])
         */
        assembly ("memory-safe") {
            let dataPointer := add(callData.offset, calldataload(callData.offset))

            // Extract the ERC7579 Executions
            executionBatch.offset := add(dataPointer, 32)
            executionBatch.length := calldataload(dataPointer)
        }
    }

    function encodeBatch(Execution[] memory executions) internal pure returns (bytes memory callData) {
        callData = abi.encode(executions);
    }

    function decodeSingle(bytes calldata executionCalldata) internal pure returns (address target, uint256 value, bytes calldata callData) {
        target = address(bytes20(executionCalldata[0:20]));
        value = uint256(bytes32(executionCalldata[20:52]));
        callData = executionCalldata[52:];
    }

    function decodeDelegateCall(bytes calldata executionCalldata) internal pure returns (address delegate, bytes calldata callData) {
        // destructure executionCallData according to single exec
        delegate = address(uint160(bytes20(executionCalldata[0:20])));
        callData = executionCalldata[20:];
    }

    function encodeSingle(address target, uint256 value, bytes memory callData) internal pure returns (bytes memory userOpCalldata) {
        userOpCalldata = abi.encodePacked(target, value, callData);
    }
}
