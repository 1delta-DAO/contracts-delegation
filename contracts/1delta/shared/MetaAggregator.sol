// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {PermitUtilsSlim} from "./permit/PermitUtilsSlim.sol";
import {DeadLogger} from "./logs/DeadLogger.sol";

// solhint-disable max-line-length

////////////////////////////////////////////////////
// Minimal meta swap aggregation contract
// - Allows simulation to validate receiver amount
// - Supports permits, exact in & out swaps
// - Swap aggregation calls are assumed to already
//   check for slippage and send funds directly to the
//   user-defined receiver
////////////////////////////////////////////////////
contract DeltaMetaAggregator is PermitUtilsSlim, DeadLogger {
    ////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////
    error SimulationResults(uint256 amountPaid, uint256 amountReceived, bytes errorData);
    error InvalidSwapCall();
    error NativeTransferFailed();
    error HasNoMsgValue();

    // NativeTransferFailed()
    bytes4 private constant NATIVE_TRANSFER_FAILED = 0xf4b3b1bc;
    // InvalidSwapCall()
    bytes4 private constant INVALID_SWAP_CALL = 0xee68db59;
    // HasNoMsgValue()
    bytes4 private constant HAS_NO_MSG_VALUE = 0x07270ad5;

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
    bytes32 private constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    /// @dev mask for address in encoded input data
    uint256 private constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    /// @dev high bit for sweep flag
    uint256 private constant SWEEP_MASK = 1 << 255;

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
     * Can only be executed any address but Permit2.
     * Calldata is validated to prevent illegitimate `transferFrom`
     * Note that the receiver address must be manually set in
     * the aggregation call, otherwise, the funds will remain in this contract
     * Ideally this function is executed after an simulation via `simSwapMeta`
     * @param permitData permit calldata (use empty data for plai transfers)
     * @param swapData swap calldata
     * @param assetInData token input address, use zero address for native - high bit signals that we have to sweep
     * @param assetOutData token output address, use zero address for native - high bit signals that we have to sweep, the address is ignored if sweep flag is not set
     * @param amountIn input amount, ignored for native transfer
     * @param approvalTarget contract approves this target when swapping (only if allowance too low)
     * @param swapTarget swap aggregation executor
     * @param receiver of assetOut - ignored if assetOut sweep flag is set to false
     */
    function swapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        bytes32 assetInData,
        bytes32 assetOutData,
        uint256 amountIn,
        address approvalTarget,
        address swapTarget,
        address receiver
    )
        external
        payable
    {
        (address asset, bool sweep) = _decodeAssetData(assetInData);
        // zero address assumes native transfer
        if (asset != address(0)) {
            // permit and pull - checks that no native is attached
            _permitAndPull(asset, amountIn, permitData);

            // approve if no allowance
            // we actually do not care what we approve as this
            // contract is not supposed to hold balances
            _approveIfNot(asset, approvalTarget);
        } else {
            // if native is the input asset,
            // we enforce that msg.value is attached
            _requireHasMsgValue();
        }

        // validate swap call
        _validateCalldata(swapData, swapTarget);

        // execute external call
        _executeExternalCall(swapData, swapTarget);

        // execute sweep of input asset if desired
        _sweepTokenIfNeeded(sweep, asset);

        // execute sweep of output asset if desired
        _handleOutputAsset(assetOutData, receiver);

        // log nothing
        _deadLog();
    }

    struct SimAmounts {
        address payAsset;
        address receiveAsset;
        uint256 amountReceived;
        uint256 amountPaid;
    }

    /**
     * Simulates the swap aggregation. Should be called before `swapMeta`
     * Always reverts with simulation results in custom error.
     * Ideally called via staticcall, the return object contains
     * the balance change of the `receiver` address.
     * Parameters are otherwise identical to `swapMeta`.
     */
    function simSwapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        bytes32 assetInData,
        bytes32 assetOutData,
        uint256 amountIn,
        address approvalTarget,
        address swapTarget,
        address receiver
    )
        external
        payable
    {
        // we use a struct to avoid stack too deep
        SimAmounts memory simAmounts;
        // read asset data
        (simAmounts.payAsset,) = _decodeAssetData(assetInData);
        (simAmounts.receiveAsset,) = _decodeAssetData(assetOutData);

        // get initial balances of receiver
        simAmounts.amountReceived = _balanceOf(simAmounts.receiveAsset, receiver);
        simAmounts.amountPaid = _balanceOf(simAmounts.payAsset, msg.sender);

        // narrow scope for stack too deep
        {
            (bool success, bytes memory returnData) = address(this).delegatecall(
                abi.encodeWithSelector(
                    DeltaMetaAggregator.swapMeta.selector, // call swap meta on sel
                    permitData,
                    swapData,
                    assetInData,
                    assetOutData,
                    amountIn,
                    approvalTarget,
                    swapTarget,
                    receiver
                )
            );
            if (!success) {
                revert SimulationResults(0, 0, returnData);
            }
        }

        // get post swap balances
        simAmounts.amountReceived = _balanceOf(simAmounts.receiveAsset, receiver) - simAmounts.amountReceived;
        simAmounts.amountPaid = simAmounts.amountPaid - _balanceOf(simAmounts.payAsset, msg.sender);
        revert SimulationResults(simAmounts.amountPaid, simAmounts.amountReceived, "");
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
                    data.length,
                    // the length must be correct or the call will fail
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
    ///     - Permit2 cannot be called
    ///     - the selector cannot be IERC20.transferFrom
    function _validateCalldata(bytes calldata data, address swapTarget) private pure {
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

    /// @dev enforce that msg.value is provided
    function _requireHasMsgValue() private view {
        assembly {
            if iszero(callvalue()) {
                mstore(0x0, HAS_NO_MSG_VALUE)
                revert(0x0, 0x4)
            }
        }
    }

    /// @dev decode asset data to asset address and sweep flag
    function _decodeAssetData(bytes32 data) private pure returns (address asset, bool sweep) {
        assembly {
            asset := and(ADDRESS_MASK, data)
            sweep := and(SWEEP_MASK, data)
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

                if iszero(call(gas(), token, 0x0, ptr, 0x44, ptr, 32)) { revert(0x0, 0x0) }
            }
            _approvedTargets[token][spender] = true;
        }
    }

    /// @dev balanceOf call in assembly, compatible for both native (use address zero for underlying) and ERC20
    function _balanceOf(address underlying, address entity) private view returns (uint256 entityBalance) {
        assembly {
            switch iszero(underlying)
            case 1 { entityBalance := balance(entity) }
            default {
                ////////////////////////////////////////////////////
                // get token balance in assembly usingn scrap space (64 bytes)
                ////////////////////////////////////////////////////

                // selector for balanceOf(address)
                mstore(0x0, ERC20_BALANCE_OF)
                // add this address as parameter
                mstore(0x4, entity)

                // call to underlying
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) { revert(0x0, 0x0) }

                entityBalance := mload(0x0)
            }
        }
    }

    /// @dev sweep asset to caller if sweep=true
    function _sweepTokenIfNeeded(bool sweep, address token) private {
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
                            mstore(0, NATIVE_TRANSFER_FAILED)
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
                        success :=
                            and(
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
                }
            }
        }
    }

    /// @dev sweep asset to receiver if sweep=true
    function _handleOutputAsset(bytes32 data, address receiver) private {
        assembly {
            if and(SWEEP_MASK, data) {
                let token := and(ADDRESS_MASK, data)
                // initialize transferAmount
                switch iszero(token)
                case 1 {
                    let transferAmount := selfbalance()
                    if gt(transferAmount, 0) {
                        if iszero(
                            call(
                                gas(),
                                receiver,
                                transferAmount,
                                0x0, // input = empty for fallback/receive
                                0x0, // input size = zero
                                0x0, // output = empty
                                0x0 // output size = zero
                            )
                        ) {
                            mstore(0, NATIVE_TRANSFER_FAILED)
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
                        mstore(add(ptr, 0x04), receiver)
                        mstore(add(ptr, 0x24), transferAmount)

                        let success := call(gas(), token, 0, ptr, 0x44, ptr, 32)

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
                }
            }
        }
    }
}
