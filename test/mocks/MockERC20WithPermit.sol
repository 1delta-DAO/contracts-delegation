// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../shared/ERC20.sol";
import "../shared/interfaces/IERC20.sol";

interface IPermit2 {
    struct PermitDetails {
        // ERC20 token address
        address token;
        // the maximum amount allowed to spend
        uint160 amount;
        // timestamp at which a spender's token allowances become invalid
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }
    /// @notice The permit message signed for a single token allownce

    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }
    /// @notice Packed allowance

    struct PackedAllowance {
        // amount allowed
        uint160 amount;
        // permission expiry
        uint48 expiration;
        // an incrementing value indexed per owner,token,and spender for each signature
        uint48 nonce;
    }

    function transferFrom(address user, address spender, uint160 amount, address token) external;

    function permit(address owner, PermitSingle memory permitSingle, bytes calldata signature) external;

    function allowance(address user, address token, address spender) external view returns (PackedAllowance memory);
}

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

    function encodeencodePermit2TransferFrom(address user, address spender, uint256 amount, address token) public pure returns (bytes memory data) {
        // transferFrom(address user, address spender, uint160 amount, address token)
        data = abi.encodeWithSelector(IPermit2.transferFrom.selector, user, spender, amount, token);
    }
}

