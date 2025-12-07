// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {PermitIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {ComposerCommands} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {MockERC20Permit} from "test/mocks/MockERC20Permit.sol";
import {MockDaiPermit} from "test/mocks/MockDaiPermit.sol";
import {Test} from "forge-std/Test.sol";

contract PermitsTest is Test, DeltaErrors {
    IComposerLike oneD;
    uint256 internal blockTimestamp;
    uint256 internal userPrivateKey = 0x1de17a0;
    address internal user = vm.addr(userPrivateKey);

    function setUp() public virtual {
        blockTimestamp = vm.getBlockTimestamp();
        oneD = ComposerPlugin.getComposer(Chains.BASE);
    }

    function signERC20Permit(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 nonce
    )
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 DOMAIN_SEPARATOR = MockERC20Permit(token).DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        return vm.sign(userPrivateKey, digest);
    }

    function encodeCompactERC20Permit(uint256 value, uint32 deadline, bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory) {
        uint256 vs = (uint256(v - 27) << 255) | uint256(s);
        return abi.encodePacked(value, deadline, r, vs);
    }

    function encodeCompactDaiPermit(uint32 nonce, uint32 expiry, bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory) {
        uint256 vs = (uint256(v - 27) << 255) | uint256(s);
        return abi.encodePacked(nonce, expiry, r, vs);
    }

    function test_unit_permit_token_permit_erc20_permit_compact() external {
        MockERC20Permit token = new MockERC20Permit(1000e18);
        token.transfer(user, 1000e18);
        uint256 value = 500e18;
        uint256 deadline = blockTimestamp + 30 minutes;
        uint256 nonce = token.nonces(user);

        (uint8 v, bytes32 r, bytes32 s) = signERC20Permit(address(token), user, address(oneD), value, deadline, nonce);
        bytes memory permitData = encodeCompactERC20Permit(value, uint32(deadline + 1), r, s, v);
        bytes memory data = CalldataLib.encodePermit(PermitIds.TOKEN_PERMIT, address(token), permitData);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(token.allowance(user, address(oneD)), value);
    }

    function test_unit_permit_token_permit_dai_like_compact() external {
        MockDaiPermit token = new MockDaiPermit(1000e18);
        token.transfer(user, 1000e18);
        uint32 nonce = 0;
        uint32 expiry = uint32(blockTimestamp + 30 minutes);
        bool allowed = true;

        bytes32 DOMAIN_SEPARATOR = token.DOMAIN_SEPARATOR();
        bytes32 PERMIT_TYPEHASH = 0xea2aa0a1eb11a72f148e9175bced81425729a267e49f3cbff88e635cfbc0b681;
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, user, address(oneD), nonce, expiry, allowed));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        bytes memory permitData = encodeCompactDaiPermit(nonce, uint32(expiry + 1), r, s, v);
        bytes memory data = CalldataLib.encodePermit(PermitIds.TOKEN_PERMIT, address(token), permitData);

        vm.prank(user);
        oneD.deltaCompose(data);

        assertEq(token.allowance(user, address(oneD)), type(uint256).max);
    }

    function test_unit_permit_token_permit_expired_deadline() external {
        MockERC20Permit token = new MockERC20Permit(1000e18);
        token.transfer(user, 1000e18);
        uint256 value = 500e18;
        uint256 deadline = blockTimestamp - 1;
        uint256 nonce = token.nonces(user);

        (uint8 v, bytes32 r, bytes32 s) = signERC20Permit(address(token), user, address(oneD), value, deadline, nonce);
        bytes memory permitData = encodeCompactERC20Permit(value, uint32(deadline + 1), r, s, v);
        bytes memory data = CalldataLib.encodePermit(PermitIds.TOKEN_PERMIT, address(token), permitData);

        vm.prank(user);
        vm.expectRevert("EXPIRED");
        oneD.deltaCompose(data);
    }

    function test_unit_permit_token_permit_invalid_length() external {
        bytes memory invalidData = abi.encodePacked(uint256(123));
        bytes memory data = CalldataLib.encodePermit(PermitIds.TOKEN_PERMIT, address(0xdead), invalidData);

        vm.prank(user);
        vm.expectRevert();
        oneD.deltaCompose(data);
    }
}
