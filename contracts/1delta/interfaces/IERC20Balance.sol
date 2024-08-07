// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

interface IERC20Balance {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}
