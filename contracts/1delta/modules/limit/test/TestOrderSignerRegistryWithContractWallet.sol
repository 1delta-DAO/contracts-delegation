// SPDX-License-Identifier: BUSL 1.1

pragma solidity ^0.8.24;

import "../../../../external-protocols/openzeppelin/access/Ownable.sol";
import "../../../../external-protocols/openzeppelin/token/ERC20/IERC20.sol";
import "../INativeOrders.sol";

contract TestOrderSignerRegistryWithContractWallet is Ownable {
    INativeOrders immutable proxy;

    constructor(INativeOrders _proxy) {
        proxy = _proxy;
    }

    function registerAllowedOrderSigner(address signer, bool allowed) external onlyOwner {
        proxy.registerAllowedOrderSigner(signer, allowed);
    }

    function approveERC20(address token, address spender, uint256 value) external onlyOwner {
        IERC20(token).approve(spender, value);
    }
}
