// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

abstract contract CTokenSignatures {
    bytes4 public constant CTOKEN_TRANSFER_TO_SELECTOR = bytes4(keccak256("transfer(address,uint256)"));
    bytes4 public constant CTOKEN_TRANSFER_FROM_SELECTOR = bytes4(keccak256("transferFrom(address,address,uint256)"));
    bytes4 public constant CTOKEN_APPROVE_SELECTOR = bytes4(keccak256("approve(address,uint256)"));
    bytes4 public constant CTOKEN_ALLOWANCE_SELECTOR = bytes4(keccak256("allowance(address,address)"));
    bytes4 public constant CTOKEN_BALANCE_OF_SELECTOR = bytes4(keccak256("balanceOf(address)"));
    bytes4 public constant CTOKEN_BALANCE_OF_UNDERLYING_SELECTOR = bytes4(keccak256("balanceOfUnderlying(address)"));
    bytes4 public constant CTOKEN_MINT_SELECTOR = bytes4(keccak256("mint(uint256)"));
    bytes4 public constant CTOKEN_REDEEM_SELECTOR = bytes4(keccak256("redeem(uint256)"));
    bytes4 public constant CTOKEN_REDEEM_UNDERLYING_SELECTOR = bytes4(keccak256("redeemUnderlying(uint256)"));
    bytes4 public constant CTOKEN_BORROW_SELECTOR = bytes4(keccak256("borrow(uint256)"));
    bytes4 public constant CTOKEN_REPAY_BORROW_SELECTOR = bytes4(keccak256("repayBorrow(uint256)"));
}
