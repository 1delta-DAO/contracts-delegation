// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library FlashDataLib {
    function getAssetAndAmount(bytes calldata data) internal pure returns (address asset, uint256 amount) {
        assembly {
            asset := shr(96, calldataload(data.offset))
            amount := calldataload(add(data.offset, 20))
        }
    }
}
