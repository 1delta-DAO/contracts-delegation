// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "../../../../../openzeppelin/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private immutable DECIMALS;

    constructor(
        string memory name_, 
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        DECIMALS = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    function faucet (uint256 amount) external {
        _mint(msg.sender, amount);
    }
}