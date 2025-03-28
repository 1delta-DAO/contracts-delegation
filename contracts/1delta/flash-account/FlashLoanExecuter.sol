// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ExecutionLock} from "./common/ExecutionLock.sol";

abstract contract FlashLoanExecuter is ExecutionLock {
    bytes32 constant ARRAY_LENGTH_MISMATCH = 0xa24a13a600000000000000000000000000000000000000000000000000000000; // ArrayLengthMismatch()

    /// @notice Execute a flash loan
    /// @param flashLoanProvider The destination address
    /// @param data The calldata to execute
    function executeFlashLoan(address flashLoanProvider, bytes calldata data) public onlyAuthorized_ setInExecution {
        __call(flashLoanProvider, 0, data);
    }

    /**
     * @dev Aave simple flash loan
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address,
        bytes calldata params // user params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * @dev Aave V2 flash loan callback
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        address,
        bytes calldata params
    ) external requireInExecution returns (bool) {
        // forward execution
        _decodeAndExecute(params);

        return true;
    }

    /**
     * @dev Balancer flash loan
     */
    function receiveFlashLoan(address[] calldata, uint256[] calldata, uint256[] calldata, bytes calldata params)
        external
        requireInExecution
    {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * @dev BalancerV3 flash loan
     */
    function receiveFlashLoan(bytes calldata data) external requireInExecution {
        // execute further operations
        _decodeAndExecute(data);
    }

    /**
     * @dev Morpho flash loan
     */
    function onMorphoFlashLoan(uint256, bytes calldata params) external requireInExecution {
        // execute further operations
        _decodeAndExecute(params);
    }

    /**
     * @dev Internal function to decode batch calldata
     */
    function _decodeAndExecute(bytes calldata params) internal {
        (address[] memory dest, uint256[] memory value, bytes[] memory func) =
            abi.decode(params, (address[], uint256[], bytes[]));
        if (dest.length != func.length || dest.length != value.length) {
            assembly {
                mstore(0x0, ARRAY_LENGTH_MISMATCH)
                revert(0x0, 0x04)
            }
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; i++) {
            __call(dest[i], value[i], func[i]);
        }
    }

    function __call(address target, uint256 value, bytes memory data) internal virtual;
    function __onlyAuthorized() internal view virtual;

    modifier onlyAuthorized_() {
        __onlyAuthorized();
        _;
    }
}
