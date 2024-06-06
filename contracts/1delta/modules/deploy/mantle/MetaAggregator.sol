// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

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
contract DeltaMetaAggregator {
    ////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////
    error SimulationResults(bool success, uint256 amountReceived, string data);
    error InvalidTarget();
    error NotOwner();
    error Paused();
    error HasMsgValue();

    ////////////////////////////////////////////////////
    // State
    ////////////////////////////////////////////////////

    /// @notice maps approvalTarget to swapTarget to bool
    mapping(address => mapping(address => bool)) private _validTargets;
    /// @notice contract owner
    address public OWNER;

    ////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////
    uint256 private constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

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

    function swapMeta(
        address assetIn,
        uint256 amountIn,
        address approvalTarget,
        address swapTarget,
        bytes calldata swapData //
    ) external payable {
        // zero address assumes native transfer
        if (assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();
            // pull balance
            _transferERC20TokensFrom(assetIn, amountIn);
            // approve if no allowance
            _approveIfBelow(assetIn, approvalTarget, amountIn);
        }
        // validates approval target and
        _validateCall(approvalTarget, swapTarget);

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

    function simSwapMeta(
        address assetIn,
        uint256 amountIn,
        address assetOut,
        address receiver,
        address approvalTarget,
        address swapTarget,
        bytes calldata swapData //
    ) external payable returns (uint256 amountReceived) {
        // zero address assumes native transfer
        if (assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();
            // pull balance
            _transferERC20TokensFrom(assetIn, amountIn);
            // approve if no allowance
            _approveIfBelow(assetIn, approvalTarget, amountIn);
        }

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

    /// @dev chcecks whether both addresses are validTargets
    function _validateCall(address approvalTarget, address swapTarget) private view {
        if (!_validTargets[approvalTarget][swapTarget]) revert InvalidTarget();
    }

    /// @dev Calls `IERC20Token(token).approve()` and sets the allowance to the
    ///      maximum if the current approval is not already >= an amount.
    ///      Reverts if the return data is invalid or the call reverts.
    /// @param token The address of the token contract.
    /// @param spender The address that receives an allowance.
    /// @param amount The minimum allowance needed.
    function _approveIfBelow(address token, address spender, uint256 amount) private {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // get allowance and validate returndata
            ////////////////////////////////////////////////////
            mstore(ptr, 0xdd62ed3e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x4), address())
            mstore(add(ptr, 0x24), spender)
            // call to token
            // success is false or return data not provided
            if or(iszero(staticcall(gas(), token, ptr, 0x44, ptr, 0x20)), lt(returndatasize(), 0x20)) {
                revert(ptr, returndatasize())
            }
            // approve if necessary
            if lt(mload(ptr), amount) {
                ////////////////////////////////////////////////////
                // Approve, at this point it is clear that the target is nonzero
                ////////////////////////////////////////////////////
                // selector for approve(address,uint256)
                mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 0x04), spender)
                mstore(add(ptr, 0x24), MAX_UINT)

                if iszero(call(gas(), token, 0, ptr, 0x44, ptr, 32)) {
                    revert(ptr, returndatasize())
                }
            }
        }
    }

    // balanceOf call in assembly for smaller contract size
    function _balanceOf(address underlying, address entity) private view returns (uint256 entityBalance) {
        assembly {
            switch eq(underlying, 0)
            case 1 {
                entityBalance := balance(entity)
            }
            default {
                ////////////////////////////////////////////////////
                // get token balance in assembly usingn scrap space (64 bytes)
                ////////////////////////////////////////////////////

                // selector for balanceOf(address)
                mstore(0x0, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                // add this address as parameter
                mstore(0x4, entity)

                // call to underlying
                if iszero(staticcall(gas(), underlying, 0x0, 0x24, 0x0, 0x20)) {
                    revert(0, 0)
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

    /// @dev Transfers ERC20 tokens from `caller()` to `address()`.
    /// @param token The token to spend.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20TokensFrom(address token, uint256 amount) private {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), caller())
            mstore(add(ptr, 0x24), address())
            mstore(add(ptr, 0x44), amount)

            let success := call(gas(), token, 0, ptr, 0x64, ptr, 32)

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
