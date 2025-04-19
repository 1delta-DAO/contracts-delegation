// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Masks} from "../../../shared/masks/Masks.sol";
import {DexTypeMappings} from "../../swappers/dex/DexTypeMappings.sol";
import {QuoterUtils} from "./utils/QuoterUtils.sol";

interface IBalancerV3VaultSelectors {
    // these two will only work with `eth_call` off-chain
    function quoteAndRevert(bytes calldata data) external returns (bytes memory);

    function quote(bytes calldata data) external returns (bytes memory);

    // this one can be called in forge

    function unlock(bytes calldata data) external;
}

abstract contract BalancerV3Quoter is QuoterUtils, Masks {
    constructor() {}

    /**
     * Callback from uniswap V4 type singletons
     * As Balancer V3 shares the same trigger selector and (unlike this one) has
     * a custom selector provided, we need to skip this part of the data
     * This is mainly done to not have duplicate code and maintain
     * the same level of security by callback validation for both DEX types
     */
    function balancerQueryCallback(bytes calldata data) external returns (uint256) {
        uint256 currentOffset;
        uint256 amountIn;
        address tokenIn;
        address tokenOut;
        assembly {
            currentOffset := data.offset
            amountIn := shr(128, calldataload(currentOffset))
            tokenIn := shr(96, calldataload(add(currentOffset, 16)))
            tokenOut := shr(96, calldataload(add(currentOffset, 36)))
            currentOffset := add(currentOffset, 56)
        }

        _simSwapBalancerV3ExactInGeneric(
            amountIn,
            tokenIn, //
            tokenOut,
            currentOffset
        );
    }

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 20             | manager              |
     * | 40     | 1              | payFlag              |
     * | 41     | 2              | calldataLength       | <- this here might be pool-dependent, cannot be used as flag
     * | 43     | calldataLength | calldata             |
     */
    function _getBalancerV3TypeAmountOut(
        uint256 fromAmount,
        address tokenIn,
        address tokenOut,
        uint256 currentOffset
    )
        internal
        returns (uint256 receivedAmount, uint256)
    {
        address manager;
        uint256 clLength;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // read the manager address
            let data := calldataload(add(currentOffset, 20))
            clLength := and(UINT16_MASK, shr(64, data))
            manager := shr(96, data)
        }
        bytes calldata calldataForCallback;
        assembly {
            calldataForCallback.offset := currentOffset
            calldataForCallback.length := add(43, clLength)
        }
        try IBalancerV3VaultSelectors(manager).unlock(
            abi.encodeCall(
                this.balancerQueryCallback,
                abi.encodePacked(
                    // add quoite-relevant data
                    uint128(fromAmount),
                    tokenIn, //
                    tokenOut,
                    // ,
                    calldataForCallback
                )
            )
        ) {} catch (bytes memory result) {
            receivedAmount = abi.decode(result, (uint256));
            assembly {
                currentOffset := add(add(currentOffset, 43), clLength)
            }
            return (receivedAmount, currentOffset);
        }

        revert("Should not succeed");
    }

    /**
     * We need all these selectors for executing a single swap
     */
    bytes32 private constant SWAP = 0x2bfb780c00000000000000000000000000000000000000000000000000000000;

    /*
     * | Offset | Length (bytes) | Description          |
     * |--------|----------------|----------------------|
     * | 0      | 20             | pool                 |
     * | 20     | 20             | manager              |
     * | 40     | 1              | payFlag              |
     * | 41     | 2              | calldataLength       | <- this here might be pool-dependent, cannot be used as flag
     * | 42     | calldataLength | calldata             |
     */
    function _simSwapBalancerV3ExactInGeneric(
        uint256 fromAmount,
        address tokenIn, //
        address tokenOut,
        uint256 currentOffset
    )
        internal
    {
        uint256 tempVar;
        // enum SwapKind {
        //     EXACT_IN,
        //     EXACT_OUT
        // }
        // struct VaultSwapParams {
        //     SwapKind kind; 4
        //     address pool; 36
        //     IERC20 tokenIn; 68
        //     IERC20 tokenOut; 100
        //     uint256 amountGivenRaw; 132
        //     uint256 limitRaw; 164
        //     bytes userData; (196, 228, 260 - X)
        // }
        ////////////////////////////////////////////
        // This is the function selector we need
        ////////////////////////////////////////////
        // function swap(
        //     VaultSwapParams memory vaultSwapParams
        // )
        //     external
        //     returns (uint256 amountCalculated, uint256 amountIn, uint256 amountOut)

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            // read the hook address and insta store it to keep stack smaller
            mstore(add(ptr, 132), shr(96, calldataload(currentOffset)))
            let pool := shr(96, calldataload(currentOffset))
            // skip hook
            currentOffset := add(currentOffset, 20)
            // read the pool address
            let vault := calldataload(currentOffset)
            // skip vault plus params
            currentOffset := add(currentOffset, 23)

            // pay flag
            tempVar := and(UINT8_MASK, shr(88, vault))
            let clLength := and(UINT16_MASK, shr(72, vault))
            vault := shr(96, vault)
            // Prepare external call data
            // Store swap selector
            mstore(ptr, SWAP)
            mstore(add(ptr, 4), 0) // exact in
            mstore(add(ptr, 36), pool)
            mstore(add(ptr, 68), tokenIn)
            mstore(add(ptr, 100), tokenOut)
            mstore(add(ptr, 132), fromAmount)
            mstore(add(ptr, 164), 1)
            mstore(add(ptr, 196), 0xe0)
            mstore(add(ptr, 228), clLength)

            if xor(0, clLength) {
                // Store further calldata for the pool
                calldatacopy(add(ptr, 260), currentOffset, clLength)
                currentOffset := add(currentOffset, clLength)
            }
            // Perform the external 'swap' call
            if iszero(call(gas(), vault, 0, ptr, add(260, clLength), ptr, 0x60)) {
                returndatacopy(0, 0, returndatasize()) // Copy the error message to the start of memory
                revert(0, returndatasize()) // Revert with the error message
            }

            // get real amounts
            fromAmount := mload(add(ptr, 0x20))
            tempVar := mload(add(ptr, 0x40))

            mstore(ptr, tempVar)
            revert(ptr, 32)
        }
    }
}
