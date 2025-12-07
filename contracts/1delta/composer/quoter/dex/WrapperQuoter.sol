// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

// solhint-disable max-line-length

/**
 * @title Quoter for wrapper
 */
abstract contract WrapperQuoter {
    /// @dev  previewDeposit(...)
    bytes32 private constant ERC4626_PREVIEW_DEPOSIT = 0xef8b30f700000000000000000000000000000000000000000000000000000000;

    /// @dev  previewRedeem(...)
    bytes32 private constant ERC4626_PREVIEW_REDEEM = 0x4cdad50600000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Quotes amountOut for wrapper operations (ERC4626 vaults)
     * @dev This one is for overriding the DEX implementation
     * @param assetIn Input asset address
     * @param assetOut Output asset address
     * @param amount Input amount
     * @param currentOffset Current position in the calldata
     * @return amountOut Output amount
     * @return operationThenOffset Updated calldata offset after processing
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description         |
     * |--------|----------------|---------------------|
     * | 0      | 1              | operation           |
     * | 1      | 1              | pay config          | <- 0: caller pays; 1: contract pays; greater: pre-funded
     */
    function _quoteWrapperExactIn(
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 currentOffset
    )
        internal
        virtual
        returns (uint256 amountOut, uint256 operationThenOffset)
    {
        assembly {
            operationThenOffset := calldataload(currentOffset)
            // shift operation to lowest byte
            switch shr(248, operationThenOffset)
            case 0 { amountOut := amount }
            // the other 2 cases are the vaults
            case 1 {
                mstore(0, ERC4626_PREVIEW_DEPOSIT)
                mstore(0x4, amount) // assets
                if iszero(call(gas(), assetOut, 0x0, 0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0x0, returndatasize())
                }
                amountOut := mload(0)
            }
            default {
                // this one should not need an approve
                mstore(0, ERC4626_PREVIEW_REDEEM)
                mstore(0x4, amount) // shares
                if iszero(call(gas(), assetIn, 0x0, 0, 0x24, 0x0, 0x20)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0x0, returndatasize())
                }
                amountOut := mload(0)
            }
            operationThenOffset := add(currentOffset, 2)
        }
        return (amountOut, operationThenOffset);
    }
}
