// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "./ERC20.sol";
import "../../1delta/interfaces/permit/IPermit2.sol";

contract MockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }

    // IERC20Permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256, /* deadline */
        uint8, /* v */
        bytes32, /* r */
        bytes32 /* s */
    )
        external
    {
        _approve(owner, spender, value);
    }

    // IDaiLikePermit
    function permit(
        address holder,
        address spender,
        uint256, /* nonce */
        uint256, /* expiry */
        bool, /* allowed */
        uint8, /* v */
        bytes32, /* r */
        bytes32 /* s */
    )
        external
    {
        _approve(holder, spender, type(uint256).max);
    }

    function encodeERC20Permit(address owner, address spender, uint256 value) public pure returns (bytes memory data) {
        // IERC20Permit.permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        data = abi.encode(owner, spender, value, uint256(0), uint8(0), bytes32(""), bytes32(""));
    }

    function encodeCompactERC20Permit(uint256 value) external pure returns (bytes memory data) {
        // Compact IERC20Permit.permit(uint256 value, uint32 deadline, uint256 r, uint256 vs)
        return abi.encodePacked(value, uint32(0), uint256(0), uint256(0));
    }

    function encodeDaiLikePermit(address holder, address spender) public pure returns (bytes memory data) {
        // IDaiLikePermit.permit(address holder, address spender,
        // uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s)
        data = abi.encode(holder, spender, uint256(0), uint256(0), true, uint8(0), bytes32(""), bytes32(""));
    }

    function encodeCompactDaiLikePermit() external pure returns (bytes memory data) {
        // Compact IDaiLikePermit.permit(uint32 nonce, uint32 expiry, uint256 r, uint256 vs)
        return abi.encodePacked(uint32(0), uint32(0), uint256(0), uint256(0));
    }

    function encodeTransferFrom(address sender, address recipient, uint256 amount) public pure returns (bytes memory data) {
        data = abi.encodeWithSelector(IERC20.transferFrom.selector, sender, recipient, amount);
    }

    function encodePermit2TransferFrom(address user, address spender, uint256 amount, address token) public pure returns (bytes memory data) {
        // transferFrom(address user, address spender, uint160 amount, address token)
        data = abi.encodeWithSelector(IPermit2.transferFrom.selector, user, spender, amount, token);
    }
}
