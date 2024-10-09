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
}
