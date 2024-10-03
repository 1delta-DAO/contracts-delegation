// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./ERC20.sol";

contract MockRouter {
    uint payoutAmount;
    address token;

    constructor(address payoutToken) {
        token = payoutToken;
    }

    function setPayout(uint amount) external {
        payoutAmount = amount;
    }

    function swap(address assetIn, uint amountIn, address to) public {
        ERC20(assetIn).transferFrom(msg.sender, address(this), amountIn);
        ERC20(token).transfer(to, payoutAmount);
    }

    function encodeSwap(address assetIn, uint amountIn, address to) public pure returns (bytes memory data) {
        data = abi.encodeWithSelector(this.swap.selector, assetIn, amountIn, to);
    }

    function encodePermit1inch(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory data) {
        data = abi.encode(owner, spender, value, deadline, v, r, s);
    }

    function encodeCompactPermit(uint256 value, uint32 deadline, uint256 r, uint256 vs) external pure returns (bytes memory data) {
        // Compact IERC20Permit.permit(uint256 value, uint32 deadline, uint256 r, uint256 vs)
        return abi.encodePacked(value, deadline, r, vs);
    }
}
