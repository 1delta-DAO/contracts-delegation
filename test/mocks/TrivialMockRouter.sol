// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../shared/ERC20.sol";

contract TrivialMockRouter {
    uint256 payoutAmount;
    address token;

    constructor(address payoutToken) {
        token = payoutToken;
    }

    function setPayout(uint256 amount) external {
        payoutAmount = amount;
    }

    function swap(address assetIn, uint256 amountIn, address to) public {
        ERC20(assetIn).transferFrom(msg.sender, address(this), amountIn);
        if (token != address(0)) ERC20(token).transfer(to, payoutAmount);
        else payable(to).call{value: payoutAmount}("");
    }

    function encodeSwap(address assetIn, uint256 amountIn, address to) public pure returns (bytes memory data) {
        data = abi.encodeWithSelector(this.swap.selector, assetIn, amountIn, to);
    }

    receive() external payable {}
}

