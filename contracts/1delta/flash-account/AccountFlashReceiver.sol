// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

abstract contract UniversalFlashLoanReceiver {
    bytes4 internal constant INVALID_CALLER = 0x48f5c3ed;
    address internal constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 internal constant ENTRY_SLOT = 0xff0471b67e4632a86905e3993f5377c608866007c59224eed7731408a9f3f8b5;

    error ArrayLengthMismatch();

    function _setInExecution() internal {
        assembly {
            sstore(ENTRY_SLOT, 1)
        }
    }

    function _validateExecutopm() internal {
        assembly {
            sstore(ENTRY_SLOT, 1)
        }
    }

    function _unsetInExecution() internal {
        assembly {
            sstore(ENTRY_SLOT, 2)
        }
    }

    function _validateAaveFlashLoan(uint256 callerId) internal view {
        assembly {
            switch callerId
            case 0 {
                if xor(caller(), BALANCER_VAULT) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
    }

    /** Aave simple flash loan */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    ) external returns (bool) {
        uint256 callerId;
        assembly {
            if xor(address(), initiator) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            callerId := shl(240, calldataload(params.offset))
            // adjust calldata for initial Id
            params.offset := add(params.offset, 2)
            params.length := sub(params.length, 2)
        }
        _validateAaveFlashLoan(callerId);
        _decodeAndExecute(params);

        return true;
    }

    function _validateBalancerFlashLoan(uint256 callerId) internal view {
        assembly {
            switch callerId
            case 0 {
                if xor(caller(), BALANCER_VAULT) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }
        }
    }

    /** Balancer flash loan */
    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external {
        uint256 callerId;
        assembly {
            callerId := shl(240, calldataload(params.offset))
            // adjust calldata for initial Id
            params.offset := add(params.offset, 2)
            params.length := sub(params.length, 2)
        }
        // validate caller
        _validateBalancerFlashLoan(callerId);

        // set flag for entry
        _setInExecution();

        // execute furhter operations
        _decodeAndExecute(params);

        // unset execution flag
        _unsetInExecution();
    }

    function _decodeAndExecute(bytes calldata params) internal {
        (
            address[] memory dest, //
            uint256[] memory value,
            bytes[] memory func
        ) = abi.decode(params, (address[], uint256[], bytes[]));
        if (dest.length != func.length || dest.length != value.length) {
            revert ArrayLengthMismatch();
        }
        uint256 length = dest.length;
        for (uint256 i = 0; i < length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        assembly ("memory-safe") {
            let succ := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0)

            if iszero(succ) {
                let fmp := mload(0x40)
                returndatacopy(fmp, 0x00, returndatasize())
                revert(fmp, returndatasize())
            }
        }
    }
}
