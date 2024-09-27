// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {PermitUtils} from "./permit/PermitUtils.sol";

////////////////////////////////////////////////////
// Minimal meta swap aggregation contract
// - Allows simulation to validate receiver amount
// - Owner can enable/disable valid swap targets
// - Swap aggregation calls are assumed to already
//   check for slippage and send funds directly to the
//   user-defined receiver
// - Owner can rescue funds in case the aggregator has
//   this contract as receiver address
////////////////////////////////////////////////////
contract DeltaMetaAggregatorWithPermit is PermitUtils {
    ////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////
    error SimulationResults(bool success, uint256 amountReceived, string data);
    error InvalidSwapCall();
    error NotOwner();
    error Paused();
    error HasMsgValue();

    ////////////////////////////////////////////////////
    // State
    ////////////////////////////////////////////////////

    /// @notice maps approvalTarget to swapTarget to bool
    mapping(address => mapping(address => bool)) private _validTargets;
    /// @notice maps token to approvalTarget to bool
    mapping(address => mapping(address => bool)) private _approvedTargets;
    /// @notice contract owner
    address public OWNER;

    ////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////
    
    /// @dev maximum uint256 - used for approvals
    uint256 private constant MAX_UINT_256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @dev mask for selector in calldata
    bytes32 internal constant SELECTOR_MASK = 0xffffffff00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for approve(address,uint256)
    bytes32 internal constant ERC20_APPROVE = 0x095ea7b300000000000000000000000000000000000000000000000000000000;

    /// @dev selector for transferFrom(address,address,uint256)
    bytes32 internal constant ERC20_TRANSFER_FROM = 0x23b872dd00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for allowance(address,address)
    bytes32 internal constant ERC20_ALLOWANCE = 0xdd62ed3e00000000000000000000000000000000000000000000000000000000;

    /// @dev selector for balanceOf(address)
    bytes32 internal constant ERC20_BALANCE_OF = 0x70a0823100000000000000000000000000000000000000000000000000000000;

    ////////////////////////////////////////////////////
    // Constructor, assigns initial owner
    ////////////////////////////////////////////////////

    constructor() {
        OWNER = msg.sender;
    }

    ////////////////////////////////////////////////////
    // Receive function for native swaps
    ////////////////////////////////////////////////////

    receive() external payable {}

    ////////////////////////////////////////////////////
    // Modifier
    ////////////////////////////////////////////////////

    modifier onlyOwner() {
        if (msg.sender != OWNER) revert NotOwner();
        _;
    }

    ////////////////////////////////////////////////////
    // Owner functions
    ////////////////////////////////////////////////////

    function transferOwnership(address newOwner) external onlyOwner {
        OWNER = newOwner;
    }

    function setValidTarget(address approvalTarget, address swapTarget, bool value) external onlyOwner {
        _validTargets[approvalTarget][swapTarget] = value;
    }

    function rescueFunds(address asset) external onlyOwner {
        if (asset == address(0)) {
            uint256 balance = address(this).balance;
            if (balance != 0) {
                (bool success, ) = payable(msg.sender).call{value: balance}("");
                if (!success) revert();
            }
        } else {
            uint256 balance = _balanceOf(asset, address(this));
            if (balance != 0) _transferERC20Tokens(asset, msg.sender, balance);
        }
    }

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
     */
    function swapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        address assetIn,
        uint256 amountIn,
        address approvalTarget,
        address swapTarget
    ) external payable {
        // zero address assumes native transfer
        if (assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();

            // permit
            if (permitData.length > 0) {
                uint256 permitOffset;
                assembly {
                    permitOffset := permitData.offset
                }
                _tryPermit(assetIn, permitOffset, permitData.length);

                // pull balance
                if (permitData.length == 96 || permitData.length == 352) {
                    _transferFromPermit2(assetIn, address(this), amountIn);
                } else {
                    _transferERC20TokensFrom(assetIn, amountIn);
                }
            }
            // approve if no allowance
            // we actually do not care what we approve as this
            // contract is not supposed to hold balances
            _approveIfNot(assetIn, approvalTarget);
        }

        // validate swap call
        _validateCalldata(swapTarget, swapData);

        (bool success, bytes memory returnData) = swapTarget.call{value: msg.value}(swapData);
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (returnData.length < 68) revert();
            assembly {
                returnData := add(returnData, 0x04)
            }
            revert(abi.decode(returnData, (string)));
        }
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
     */
    function simSwapMeta(
        bytes calldata permitData,
        bytes calldata swapData,
        address assetIn,
        uint256 amountIn,
        address assetOut,
        address receiver,
        address approvalTarget,
        address swapTarget
    ) external payable returns (uint256 amountReceived) {
        // zero address assumes native transfer
        if (assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();

            // permit
            if (permitData.length > 0) _tryPermit(assetIn, 0, permitData.length);

            // pull balance
            if (permitData.length == 96 || permitData.length == 352) {
                _safeTransferFromPermit2(assetIn, msg.sender, address(this), amountIn);
            } else {
                _transferERC20TokensFrom(assetIn, amountIn);
            }

            // approve if no allowance
            _approveIfNot(assetIn, approvalTarget);
        }

        // get initial balane of receiver
        uint256 before = _balanceOf(assetOut, receiver);

        (bool success, bytes memory returnData) = swapTarget.call{value: msg.value}(swapData);
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (returnData.length < 68) revert();
            assembly {
                returnData := add(returnData, 0x04)
            }
            revert SimulationResults(false, 0, abi.decode(returnData, (string)));
        }

        // get net amount received
        amountReceived = _balanceOf(assetOut, receiver) - before;
        revert SimulationResults(success, amountReceived, "");
    }

    ////////////////////////////////////////////////////
    // Read functions
    ////////////////////////////////////////////////////

    function isValidTarget(address approvalTarget, address swapTarget) external view returns (bool) {
        return _validTargets[approvalTarget][swapTarget];
    }

    ////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////

    /// @dev checks that
    ///     - Permit2 cannot be arbitrarily called
    ///     - the selector cannot be ERC20 transferFrom
    function _validateCalldata(address swapTarget, bytes calldata data) private pure {
        bool hasError;
        assembly {
            // extract the selector from the calldata
            let selector := and(SELECTOR_MASK, calldataload(data.offset))

            // check if it is `transferFrom`
            if eq(selector, ERC20_TRANSFER_FROM) {
                hasError := true
            }
            // check if the target is permit2
            if eq(swapTarget, PERMIT2) {
                hasError := true
            }
        }
        if (hasError) revert InvalidSwapCall();
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

    /// @dev Transfers ERC20 tokens from ourselves to `to`.
    /// @param token The token to spend.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20Tokens(address token, address to, uint256 amount) private {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transfer(address,uint256)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), to)
            mstore(add(ptr, 0x24), amount)

            let success := call(gas(), token, 0x0, ptr, 0x44, ptr, 32)

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
                returndatacopy(ptr, 0x0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }

    /// @dev Transfers ERC20 tokens from msg.sender to address(this).
    /// @param token The token to spend.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20TokensFrom(address token, uint256 amount) private {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, ERC20_TRANSFER_FROM)
            mstore(add(ptr, 0x04), caller())
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), token, 0x0, ptr, 0x64, ptr, 32)

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
                returndatacopy(ptr, 0x0, rdsize)
                revert(ptr, rdsize)
            }
        }
    }
}
