// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * \
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {ERC20Selectors} from "../selectors/ERC20Selectors.sol";
import {Masks} from "../masks/Masks.sol";

/**
 * @title Curve swapper contract
 * @notice We do Curve stuff here
 */
abstract contract CurveMetaSwapper is ERC20Selectors, Masks {
    // approval slot
    bytes32 private constant CALL_MANAGEMENT_APPROVALS = 0x1aae13105d9b6581c36534caba5708726e5ea1e03175e823c989a5756966d1f3;

    /**
     * Meta pool zap selectors - first argument is another curve pool
     */

    /// @notice selector exchange(address,uint256,uint256,uint256,uint256)
    bytes32 private constant EXCHANGE_META = 0x64a1455800000000000000000000000000000000000000000000000000000000;

    /// @notice selector exchange(address,uint256,uint256,uint256,uint256,bool,address)
    bytes32 private constant EXCHANGE_META_RECEIVER = 0xb837cc6900000000000000000000000000000000000000000000000000000000;

    /// @notice Curve meta params lengths
    uint256 internal constant SKIP_LENGTH_CURVE_META = 65; // = 20+1+1+20+1+1
    uint256 internal constant RECEIVER_OFFSET_CURVE_META = 87; // = SKIP_LENGTH_CURVE_META+20+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE_META = 88; // = SKIP_LENGTH_CURVE_META+20+1+2
    uint256 internal constant MAX_SINGLE_LENGTH_CURVE_META_HIGH = 89; // = SKIP_LENGTH_CURVE_META+20+1+2+1

    constructor() {}

    /**
     * Swaps using a meta pool (i.e. a curve pool that has another one as underlying)
     * Data is supposed to be packed as follows
     * tokenIn | actionId | dexId | zapFactory | i | j | sm | metaPool | tokenOut
     * sm is the selector,
     * i,j are the swap indexes for the meta pool
     */
    function _swapCurveMeta(
        uint256 pathOffset,
        uint256 amountIn,
        address payer,
        address receiver //
    )
        internal
        returns (uint256 amountOut)
    {
        assembly {
            let ptr := mload(0x40)
            let tokenIn := shr(96, calldataload(pathOffset))
            ////////////////////////////////////////////////////
            // Pull funds if needed
            ////////////////////////////////////////////////////
            if xor(payer, address()) {
                // selector for transferFrom(address,address,uint256)
                mstore(ptr, ERC20_TRANSFER_FROM)
                mstore(add(ptr, 0x04), payer)
                mstore(add(ptr, 0x24), address())
                mstore(add(ptr, 0x44), amountIn)

                let success := call(gas(), tokenIn, 0, ptr, 0x64, ptr, 32)

                let rdsize := returndatasize()

                // Check for ERC20 success. ERC20 tokens should return a boolean,
                // but some don't. We accept 0-length return data as success, or at
                // least 32 bytes that starts with a 32-byte boolean true.
                success :=
                    and(
                        success, // call itself succeeded
                        or(
                            iszero(rdsize), // no return data, or
                            and(
                                iszero(lt(rdsize, 32)), // at least 32 bytes
                                eq(mload(ptr), 1) // starts with uint256(1)
                            )
                        )
                    )

                if iszero(success) {
                    returndatacopy(0, 0, rdsize)
                    revert(0, rdsize)
                }
            }

            let indexData := calldataload(add(pathOffset, 42))

            let target := shr(96, calldataload(add(pathOffset, 22)))

            ////////////////////////////////////////////////////
            // Approve zap factory funds if needed
            ////////////////////////////////////////////////////
            mstore(0x0, tokenIn)
            mstore(0x20, CALL_MANAGEMENT_APPROVALS)
            mstore(0x20, keccak256(0x0, 0x40))
            mstore(0x0, target)
            let key := keccak256(0x0, 0x40)
            // check if already approved
            if iszero(sload(key)) {
                // approveFlag
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), target)
                mstore(add(ptr, 0x24), MAX_UINT256)
                pop(call(gas(), tokenIn, 0, ptr, 0x44, ptr, 32))
                sstore(key, 1)
            }

            let selectorId := and(shr(72, indexData), 0xff)

            ////////////////////////////////////////////////////
            // Execute swap function
            ////////////////////////////////////////////////////

            // populate swap selector
            switch selectorId
            case 1 {
                // we can do it so that the receiver is incldued
                // in the call
                mstore(ptr, EXCHANGE_META_RECEIVER)
                mstore(add(ptr, 0x4), shr(96, indexData))
                mstore(add(ptr, 0x24), and(shr(88, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x44), and(shr(80, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x64), amountIn)
                mstore(add(ptr, 0x84), 0) // min out is zero, we validate slippage at the end
                mstore(add(ptr, 0xA4), 0) // useEth=false
                mstore(add(ptr, 0xC4), receiver)
                if iszero(
                    call(
                        gas(),
                        target, // zap factory
                        0x0,
                        ptr,
                        0xE4,
                        ptr,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amountOut := mload(ptr)
            }
            default {
                // otherwise, the receiver is this contract
                mstore(ptr, EXCHANGE_META)
                mstore(add(ptr, 0x4), shr(96, indexData))
                mstore(add(ptr, 0x24), and(shr(88, indexData), 0xff)) // indexIn
                mstore(add(ptr, 0x44), and(shr(80, indexData), 0xff)) // indexOut
                mstore(add(ptr, 0x64), amountIn)
                mstore(add(ptr, 0x84), 0) // min out is zero, we validate slippage at the end
                if iszero(
                    call(
                        gas(),
                        target, // zap factory
                        0x0,
                        ptr,
                        0xA4,
                        ptr,
                        0x20
                    )
                ) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }
                amountOut := mload(ptr)
                ////////////////////////////////////////////////////
                // Send funds to receiver if needed
                ////////////////////////////////////////////////////
                if xor(receiver, address()) {
                    // selector for transfer(address,uint256)
                    mstore(ptr, ERC20_TRANSFER)
                    mstore(add(ptr, 0x04), receiver)
                    mstore(add(ptr, 0x24), amountOut)
                    let success :=
                        call(
                            gas(),
                            shr(96, calldataload(add(pathOffset, 44))), // tokenIn, added 2x addr + 4x uint8
                            0,
                            ptr,
                            0x44,
                            ptr,
                            32
                        )

                    let rdsize := returndatasize()

                    // Check for ERC20 success. ERC20 tokens should return a boolean,
                    // but some don't. We accept 0-length return data as success, or at
                    // least 32 bytes that starts with a 32-byte boolean true.
                    success :=
                        and(
                            success, // call itself succeeded
                            or(
                                iszero(rdsize), // no return data, or
                                and(
                                    iszero(lt(rdsize, 32)), // at least 32 bytes
                                    eq(mload(ptr), 1) // starts with uint256(1)
                                )
                            )
                        )

                    if iszero(success) {
                        returndatacopy(0, 0, rdsize)
                        revert(0, rdsize)
                    }
                }
            }
        }
    }
}
