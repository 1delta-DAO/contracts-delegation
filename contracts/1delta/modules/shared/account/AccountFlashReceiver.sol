// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

abstract contract AccountFlashReceiver {
    error ArrayLengthMismatch();

    function _validateBalancerFlashLoan() internal {}

    function receiveFlashLoan(
        address[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata params //
    ) external {
        _validateBalancerFlashLoan();
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
