// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Balancer V2 swapper contract that uses Symmetric's vault
 * @notice Balancer V2 is fun (mostly)
 */
abstract contract BalancerSwapper {

    /// @dev Maximum Uint256 value
    uint256 private constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @dev All swaps go through the Symmetric (symm.fi) vault
    address internal constant BALANCER_V2_VAULT = 0xbccc4b4c6530F82FE309c5E845E50b5E9C89f2AD;

    /** Erc20 selectors */

    /// @dev selector for approve(address,uint256)
    bytes32 private constant ERC20_APPROVE = 0x095ea7b300000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transferFrom(address,address,uint256)
    bytes32 private constant ERC20_TRANSFER_FROM = 0x23b872dd00000000000000000000000000000000000000000000000000000000;


    /// @dev Balancer's single swap function
    bytes32 private constant BALANCER_SWAP = 0x52bbbe2900000000000000000000000000000000000000000000000000000000;

    /// @dev Balancer parameter lengths
    uint256 internal constant SKIP_LENGTH_BALANCER_V2 = 54; // = 20+1+1+32
    uint256 internal constant RECEIVER_OFFSET_BALANCER_V2 = 76;
    uint256 internal constant MAX_SINGLE_LENGTH_BALANCER_V2 = 77;
    uint256 internal constant MAX_SINGLE_LENGTH_BALANCER_V2_HIGH = 78;

    /** Call queryBatchSwap on the Balancer V2 vault.
     *  Should be avoided if possible as it executes (but reverts) state changes in the balancer vault
     *  Executes `call` and therefore is non-view
     *  Will allow to save a refund transfer since we calculate the exact amount
     *  Since we check slippage manually, the concerns mentioned in https://docs.balancer.fi/reference/contracts/query-functions.html
     *  do not apply.
     */
    function _getBalancerAmountIn(bytes32 balancerPoolId, address tokenIn, address tokenOut, uint256 amountOut) internal returns (uint256 amountIn) {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // call `queryBatchSwap` function on vB2 vault
            // This is not optimal as the call can cost
            // quite some gas for CSPs (~90k), even if we use assembly
            ////////////////////////////////////////////////////
            mstore(ptr, 0xf84d066e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), 1)
            mstore(add(ptr, 0x24), 0xe0)
            mstore(add(ptr, 0x44), 0x1e0) // FundManagement struct
            mstore(add(ptr, 0x64), 0) // sender
            mstore(add(ptr, 0x84), 0) // fromInternalBalance
            mstore(add(ptr, 0xA4), 0) // recipient
            mstore(add(ptr, 0xC4), 0) // toInternalBalance
            mstore(add(ptr, 0xE4), 1)
            mstore(add(ptr, 0x104), 0x20) // SingleSwap struct
            mstore(add(ptr, 0x124), balancerPoolId) // poolId
            mstore(add(ptr, 0x144), 0) // userDataLength
            mstore(add(ptr, 0x164), 1) // swapKind = GIVEN_OUT
            mstore(add(ptr, 0x184), amountOut) // amount
            mstore(add(ptr, 0x1A4), 0xa0)
            mstore(add(ptr, 0x1C4), 0)
            mstore(add(ptr, 0x1E4), 2)
            mstore(add(ptr, 0x204), tokenIn) // assetIn
            mstore(add(ptr, 0x224), tokenOut) // assetOut

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x244,
                    ptr,
                    0x60 // return is always array of two, we want the first value
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            amountIn := mload(add(ptr, 0x40))
        }
    }

    /** Simple exact input swap with Balancer V2. We assume `userData` in the struct to be empty */
    function _swapBalancerExactIn(address payer, uint256 amountIn, address receiver, uint256 offset) internal returns (uint256 amountOut) {
        assembly {
            // fetch swap context
            let tokenIn := shr(96, calldataload(offset))
            let tokenOut := shr(96, calldataload(add(offset, SKIP_LENGTH_BALANCER_V2)))
            let balancerPoolId := calldataload(add(offset, 22))

            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(
                    gas(),
                    tokenIn, //
                    0,
                    ptr,
                    0x64,
                    ptr,
                    32
                )

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success := and(
                    success, // call itself succeeded
                    or(
                        iszero(rdsize), // no return data, or
                        and(
                            gt(rdsize, 31), // at least 32 bytes
                            eq(mload(ptr), 1) // starts with uint256(1)
                        )
                    )
                )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }
            ////////////////////////////////////////////////////
            // Approve vault if needed
            ////////////////////////////////////////////////////
            mstore(0x0, tokenIn)
            mstore(0x20, 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3) // CALL_MANAGEMENT_APPROVALS
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, BALANCER_V2_VAULT)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), BALANCER_V2_VAULT)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
                sstore(key, 1)
            }

            ////////////////////////////////////////////////////
            // Execute swap function on B2 Vault
            ////////////////////////////////////////////////////
            mstore(ptr, BALANCER_SWAP)
            mstore(add(ptr, 0x4), 0xe0) // FundManagement struct
            mstore(add(ptr, 0x24), address()) // sender
            mstore(add(ptr, 0x44), 0) // fromInternalBalance
            mstore(add(ptr, 0x64), receiver) // receiver
            mstore(add(ptr, 0x84), 0) // toInternalBalance
            mstore(add(ptr, 0xA4), 0) // limit
            mstore(add(ptr, 0xC4), MAX_UINT256) // deadline
            mstore(add(ptr, 0xE4), balancerPoolId)
            mstore(add(ptr, 0x104), 0) // swapKind = GIVEN_IN
            mstore(add(ptr, 0x124), tokenIn) // assetIn
            mstore(add(ptr, 0x144), tokenOut) // assetOut
            mstore(add(ptr, 0x164), amountIn) // amount
            mstore(add(ptr, 0x184), 0xC0) // offest
            mstore(add(ptr, 0x1A4), 0) // userData length

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x1C4,
                    0x0,
                    0x20 // we do not use the return array
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            amountOut := mload(0x0)
        }
    }

    /** call single swap function on Balancer V2 vault */
    function _swapBalancerExactOut(
        bytes32 balancerPoolId,
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 amountOut
    ) internal {
        assembly {
            let ptr := mload(0x40)

            ////////////////////////////////////////////////////
            // Approve vault if needed
            ////////////////////////////////////////////////////
            mstore(0x0, tokenIn)
            mstore(0x20, 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3) // CALL_MANAGEMENT_APPROVALS
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, BALANCER_V2_VAULT)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), BALANCER_V2_VAULT)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
                sstore(key, 1)
            }

            ////////////////////////////////////////////////////
            // Execute swap function on B2 Vault
            ////////////////////////////////////////////////////
            mstore(ptr, BALANCER_SWAP)
            mstore(add(ptr, 0x4), 0xe0) // FundManagement struct
            mstore(add(ptr, 0x24), address()) // sender
            mstore(add(ptr, 0x44), 0) // fromInternalBalance
            mstore(add(ptr, 0x64), receiver) // receiver
            mstore(add(ptr, 0x84), 0) // toInternalBalance
            mstore(add(ptr, 0xA4), MAX_UINT256) // limit
            mstore(add(ptr, 0xC4), MAX_UINT256) // deadline
            mstore(add(ptr, 0xE4), balancerPoolId)
            mstore(add(ptr, 0x104), 1) // swapKind = GIVEN_OUT
            mstore(add(ptr, 0x124), tokenIn) // assetIn
            mstore(add(ptr, 0x144), tokenOut) // assetOut
            mstore(add(ptr, 0x164), amountOut) // amount
            mstore(add(ptr, 0x184), 0xC0) // offest
            mstore(add(ptr, 0x1A4), 0) // userData length

            if iszero(
                call(
                    gas(),
                    BALANCER_V2_VAULT,
                    0x0,
                    ptr,
                    0x1C4,
                    0x0,
                    0x0 // we do not use the return array
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
