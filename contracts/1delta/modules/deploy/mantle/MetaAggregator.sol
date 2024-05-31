// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

contract DeltaMetaAggregator {
    ////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////
    error SimulationResults(bool success, uint256 amountReceived);
    error InvalidTarget();
    error NotOwner();
    error Paused();
    error HasMsgValue();

    ////////////////////////////////////////////////////
    // State
    ////////////////////////////////////////////////////
    mapping(address => bool) public validTarget;
    address public OWNER;

    ////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////
    uint256 private constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    constructor() {
        OWNER = msg.sender;
    }

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

    function setValidTarget(address target, bool value) external onlyOwner {
        validTarget[target] = value;
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
        address _assetIn = assetIn;
        // zero address assumes native transfer
        if (_assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();
            // pull balance
            _transferERC20TokensFrom(_assetIn, msg.sender, address(this), amountIn);
            // approve if no allowance
            _approveIfBelow(_assetIn, approvalTarget, MAX_UINT);
        }

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
        address _assetIn = assetIn;
        // zero address assumes native transfer
        if (_assetIn != address(0)) {
            if (msg.value != 0) revert HasMsgValue();
            // pull balance
            _transferERC20TokensFrom(_assetIn, msg.sender, address(this), amountIn);
            // approve if no allowance
            _approveIfBelow(_assetIn, approvalTarget, MAX_UINT);
        }

        uint256 before = _balanceOf(assetOut, receiver);
        (bool success, bytes memory returnData) = swapTarget.call{value: msg.value}(swapData);
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (returnData.length < 68) revert();
            assembly {
                returnData := add(returnData, 0x04)
            }
            revert(abi.decode(returnData, (string)));
        }
        amountReceived = _balanceOf(assetOut, receiver) - before;
        revert SimulationResults(success, amountReceived);
    }

    ////////////////////////////////////////////////////
    // Internals
    ////////////////////////////////////////////////////

    /// @dev chcecks whether both addresses are validTargets
    function _validateCall(address approvalTarget, address swapTarget) private view {
        if (!validTarget[approvalTarget]) revert InvalidTarget();
        if (approvalTarget != swapTarget && !validTarget[swapTarget]) revert InvalidTarget();
    }

    /// @dev Calls `IERC20Token(token).approve()` and sets the allowance to the
    ///      maximum if the current approval is not already >= an amount.
    ///      Reverts if the return data is invalid or the call reverts.
    /// @param token The address of the token contract.
    /// @param spender The address that receives an allowance.
    /// @param amount The minimum allowance needed.
    function _approveIfBelow(address token, address spender, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40)
            ////////////////////////////////////////////////////
            // get allowance and vaidate returndata
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
    function _balanceOf(address underlying, address entity) internal view returns (uint256 entityBalance) {
        assembly {
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

    /// @dev Transfers ERC20 tokens from ourselves to `to`.
    /// @param token The token to spend.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20Tokens(address token, address to, uint256 amount) internal {
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

    /// @dev Transfers ERC20 tokens from `owner` to `to`.
    /// @param token The token to spend.
    /// @param owner The owner of the tokens.
    /// @param to The recipient of the tokens.
    /// @param amount The amount of `token` to transfer.
    function _transferERC20TokensFrom(address token, address owner, address to, uint256 amount) internal {
        assembly {
            let ptr := mload(0x40) // free memory pointer

            // selector for transferFrom(address,address,uint256)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), owner)
            mstore(add(ptr, 0x24), to)
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
