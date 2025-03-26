// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20All {
    // base
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    // credit delegation

    function approveDelegation(address delegatee, uint256 amount) external;

    function borrowAllowance(address fromUser, address toUser) external view returns (uint256);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    // compound V2
    function balanceOfUnderlying(address owner) external returns (uint);

    function borrowBalanceCurrent(address account) external returns (uint);

    // ERC4646
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function allow(address manager, bool isAllowed) external;

    // Compound v2 extended

    function enterMarkets(address[] calldata vTokens) external returns (uint[] memory);

    function exitMarket(address vToken) external returns (uint);

    function updateDelegate(address delegate, bool allowBorrows) external;
}
