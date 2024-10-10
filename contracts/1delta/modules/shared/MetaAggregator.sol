// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {PermitUtilsSlim} from "./permit/PermitUtilsSlim.sol";

////////////////////////////////////////////////////
// Minimal meta swap aggregation contract
// - Allows simulation to validate receiver amount
// - Supports permits, exact in & out swaps
// - Swap aggregation calls are assumed to already
//   check for slippage and send funds directly to the
//   user-defined receiver
////////////////////////////////////////////////////
contract DeltaMetaAggregator is PermitUtilsSlim {
    ////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////
    error SimulationResults(bool success, uint256 amountReceived, uint256 amountPaid, bytes data);

    // NativeTransferFailed()
    bytes4 internal constant NATIVE_TRANSFER = 0xf4b3b1bc;
    bytes4 internal constant INVALID_SWAP_CALL = 0xee68db59;

    ////////////////////////////////////////////////////
    // State
    ////////////////////////////////////////////////////

    /// @notice maps token to approvalTarget to bool
    mapping(address => mapping(address => bool)) private _approvedTargets;

    ////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////

    /// @dev maximum uint256 - used for approvals
    uint256 private constant MAX_UINT_256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @dev mask for selector in calldata
    bytes32 internal constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    ////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////

    constructor() {}

    ////////////////////////////////////////////////////
    // Receive function for native swaps
    ////////////////////////////////////////////////////

    receive() external payable {}

    ////////////////////////////////////////////////////
    // Swap functions
    ////////////////////////////////////////////////////

    /**
     * Executes meta aggregation swap.
     * Can only be executed on valid approval- and swap target combo.
     * Note that the receiver address has to be manually set in
     * the aggregation call, otherwise, the funds might remain in this contract
     * Ideally this function is executed after an simulation via `simSwapMeta`
     * @param permitData permit calldata
     * @param swapData swap calldata
     * @param assetIn token input address, user zero address for native
     * @param amountIn input amount, ignored for native transfer
     * @param approvalTarget approve this target when swapping (only if allowance too low)
     * @param swapTarget swap aggregation executor
     * @param sweep sweep input token for exactOut
     */
    function swapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        address assetIn,
        uint256 amountIn,
        address approvalTarget,
        address swapTarget,
        bool sweep
    ) external payable {
        // zero address assumes native transfer
        if (assetIn != address(0)) {
            // permit and pull - checks that no native is attached
            _permitAndPull(assetIn, amountIn, permitData);

            // approve if no allowance
            // we actually do not care what we approve as this
            // contract is not supposed to hold balances
            _approveIfNot(assetIn, approvalTarget);
        }

        // validate swap call
        _validateCalldata(swapTarget, swapData);

        // execute external call
        _executeExternalCall(swapData, swapTarget);

        _sweepTokenIfNeeded(sweep, assetIn);
    }

    struct SimAmounts {
        uint256 amountReceived;
        uint256 amountPaid;
    }

    /**
     * Simulates the swap aggregation. Should be called before `swapMeta`
     * Always reverts.
     * Ideally called via staticcall, the return object contains
     * the balance change of the `receiver` address.
     * @param permitData permit calldata
     * @param swapData swap calldata
     * @param assetIn token in address, zero address for native
     * @param amountIn input amount
     * @param assetOut token out, zero address for native
     * @param receiver recipient of swap
     * @param approvalTarget address to be approved
     * @param swapTarget swap aggregator
     * @param sweep sweep input token for exactOut
     */
    function simSwapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        address assetIn,
        uint256 amountIn,
        address assetOut,
        address receiver,
        address approvalTarget,
        address swapTarget,
        bool sweep
    ) external payable returns (SimAmounts memory simAmounts) {
        // get initial balane of receiver
        simAmounts.amountReceived = _balanceOf(assetOut, receiver);
        simAmounts.amountPaid = _balanceOf(assetIn, msg.sender);

        {
            (bool success, bytes memory returnData) = address(this).delegatecall(
                abi.encodeWithSelector(
                    DeltaMetaAggregator.swapMeta.selector, // call swap meta on sel
                    permitData,
                    swapData,
                    assetIn,
                    amountIn,
                    approvalTarget,
                    swapTarget,
                    sweep
                )
            );
            if (!success) {
                revert SimulationResults(false, 0, 0, returnData);
            }
        }
        // get net amount received
        simAmounts.amountReceived = _balanceOf(assetOut, receiver) - simAmounts.amountReceived;
        simAmounts.amountPaid = simAmounts.amountPaid - _balanceOf(assetIn, msg.sender);
        revert SimulationResults(true, simAmounts.amountReceived, simAmounts.amountPaid, "");
    }

    ////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////

    /// @dev executes call on target with data
    ///      -> MUST validate the selector and target first
    /// @param data calldata
    /// @param target target address
    function _executeExternalCall(bytes calldata data, address target) private {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, data.offset, data.length) // copy permit calldata
            if iszero(
                call(
                    gas(),
                    target,
                    callvalue(),
                    ptr, //
                    data.length, // the length must be correct or the call will fail
                    0x0, // output = empty
                    0x0 // output size = zero
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    /// @dev checks that
    ///     - Permit2 cannot be arbitrarily called
    ///     - the selector cannot be ERC20 transferFrom
    function _validateCalldata(address swapTarget, bytes calldata data) private pure {
        assembly {
            // extract the selector from the calldata
            let selector := and(SELECTOR_MASK, calldataload(data.offset))

            // check if it is `transferFrom`
            if eq(selector, ERC20_TRANSFER_FROM) {
                mstore(0x0, INVALID_SWAP_CALL)
                revert(0x0, 0x4)
            }
            // check if the target is permit2
            if eq(swapTarget, PERMIT2) {
                mstore(0x0, INVALID_SWAP_CALL)
                revert(0x0, 0x4)
            }
        }
    }

    /// @dev Checks approvals in storage and sets the allowance to the
    ///      maximum if the current approval is not already >= an amount.
    ///      Reverts if the return data is invalid or the call reverts.
    /// @param token The address of the token contract.
    /// @param spender The address that receives an allowance.
    function _approveIfNot(address token, address spender) private {
        // approve if necessary
        if (!_approvedTargets[token][spender]) {
            assembly {
                let ptr := mload(0x40)
                ////////////////////////////////////////////////////
                // Approve, at this point it is clear that the target is nonzero
                ////////////////////////////////////////////////////
                // selector for approve(address,uint256)
                mstore(ptr, ERC20_APPROVE)
                mstore(add(ptr, 0x04), spender)
                mstore(add(ptr, 0x24), MAX_UINT_256)

                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) {
                    revert(0x0, 0x0)
                }
            }
            _approvedTargets[token][spender] = true;
        }
    }

    /// @dev balanceOf call in assembly, compatible for both native (user address zero for underlying) and ERC20
    function _balanceOf(address underlying, address entity) private view returns (uint256 entityBalance) {
        assembly {
            switch iszero(underlying)
            case 1 {
                entityBalance := balance(entity)
            }
            default {
                ////////////////////////////////////////////////////
                // get token balance in assembly usingn scrap space (64 bytes)
                ////////////////////////////////////////////////////

                // selector for balanceOf(address)
                mstore(0x0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x4, entity)

                // call to underlying
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    revert(0x0, 0x0)
                }

                entityBalance := mload(0x0)
            }
        }
    }

    function _sweepTokenIfNeeded(bool sweep, address token) public payable {
        assembly {
            if sweep {
                // initialize transferAmount
                switch iszero(token)
                case 1 {
                    let transferAmount := selfbalance()
                    if gt(transferAmount, 0) {
                        if iszero(
                            call(
                                gas(),
                                caller(),
                                transferAmount,
                                0x0, // input = empty for fallback/receive
                                0x0, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            mstore(0, NATIVE_TRANSFER)
                            revert(0, 0x4) // revert when native transfer fails
                        }
                    }
                }
                default {
                    // selector for balanceOf(address)
                    mstore(0, ERC20_BALANCE_OF)
                    // add this address as parameter
                    mstore(0x04, address())
                    // call to token
                    pop(
                        staticcall(
                            gas(),
                            token,
                            0x0,
                            0x24,
                            0x0,
                            0x20 //
                        )
                    )
                    // load the retrieved balance
                    let transferAmount := mload(0x0)

                    if gt(transferAmount, 0) {
                        let ptr := mload(0x40) // free memory pointer

                        // selector for transfer(address,uint256)
                        mstore(ptr, ERC20_TRANSFER)
                        mstore(add(ptr, 0x04), caller())
                        mstore(add(ptr, 0x24), transferAmount)

                        let success := call(gas(), token, 0, ptr, 0x44, ptr, 32)

                        let rdsize := returndatasize()

                        // Check for ERC20 success. ERC20 tokens should return a boolean,
                        // but some don't. We accept 0-length return data as success, or at
                        // least 32 bytes that starts with a 32-byte boolean true.
                        success := and(
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
                            returndatacopy(ptr, 0, rdsize)
                            revert(ptr, rdsize)
                        }
                    }
                }
            }
        }
    }
}
