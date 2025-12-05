// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockERC20Revert {
    string public constant name = "Mock Revert Token";
    string public constant symbol = "MRT";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool public shouldRevertTransfer;
    bool public shouldRevertTransferFrom;
    bool public shouldRevertApprove;
    bool public returnFalse;

    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function setShouldRevertTransfer(bool _should) external {
        shouldRevertTransfer = _should;
    }

    function setShouldRevertTransferFrom(bool _should) external {
        shouldRevertTransferFrom = _should;
    }

    function setShouldRevertApprove(bool _should) external {
        shouldRevertApprove = _should;
    }

    function setReturnFalse(bool _should) external {
        returnFalse = _should;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (shouldRevertTransfer) {
            revert("Transfer reverted");
        }
        if (returnFalse) {
            return false;
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (shouldRevertTransferFrom) {
            revert("TransferFrom reverted");
        }
        if (returnFalse) {
            return false;
        }
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (shouldRevertApprove) {
            revert("Approve reverted");
        }
        if (returnFalse) {
            return false;
        }
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

