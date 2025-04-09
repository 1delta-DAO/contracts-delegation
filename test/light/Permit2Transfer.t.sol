// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "light/Composer.sol";
import {CalldataLib} from "./utils/CalldataLib.sol";
import {DeltaErrors} from "modules/shared/errors/Errors.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";

contract Permit2TransferTest is BaseTest, DeltaErrors {
    using CalldataLib for bytes;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 internal constant forkBlock = 26696866;

    address internal WETH;
    address internal USDC;

    OneDeltaComposerLight oneD;

    uint256 internal blockTimestamp;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);
        blockTimestamp = vm.getBlockTimestamp();
        vm.warp(blockTimestamp);

        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneD = new OneDeltaComposerLight();
    }

    // ------------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------------

    function test_light_permit2_transfer_from() public {
        uint256 initialAmount = 1000e6;
        uint256 transferAmount = 500e6;
        deal(USDC, user, initialAmount);

        vm.startPrank(user);

        IERC20All(USDC).approve(PERMIT2, type(uint256).max);

        uint48 expiration = uint48(blockTimestamp + 1 hours);
        uint48 nonce = 0; // First transaction
        uint256 sigDeadline = blockTimestamp + 1 hours;

        bytes memory signature =
            signPermit2(USDC, uint160(transferAmount), expiration, nonce, address(oneD), sigDeadline);

        IPermit2.PermitSingle memory permitSingle = IPermit2.PermitSingle({
            details: IPermit2.PermitDetails({
                token: USDC,
                amount: uint160(transferAmount),
                expiration: expiration,
                nonce: nonce
            }),
            spender: address(oneD),
            sigDeadline: sigDeadline
        });

        IPermit2(PERMIT2).permit(user, permitSingle, signature);

        bytes memory data = CalldataLib.permit2TransferFrom(USDC, address(oneD), transferAmount);

        oneD.deltaCompose(data);
        vm.stopPrank();

        assertEq(IERC20All(USDC).balanceOf(user), initialAmount - transferAmount);
        assertEq(IERC20All(USDC).balanceOf(address(oneD)), transferAmount);
    }
    // ------------------------------------------------------------------------
    // Helper functions
    // ------------------------------------------------------------------------

    function signPermit2(
        address token,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        address spender,
        uint256 sigDeadline
    ) internal view returns (bytes memory) {
        // Permit2 EIP712Domain
        bytes32 DOMAIN_SEPARATOR = IPermit2(PERMIT2).DOMAIN_SEPARATOR();

        // Permit2 permitSinglr hash
        bytes32 permitHash = hash(
            IPermit2.PermitSingle({
                details: IPermit2.PermitDetails({token: token, amount: amount, expiration: expiration, nonce: nonce}),
                spender: spender,
                sigDeadline: sigDeadline
            })
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, permitHash));

        // Sign the digest
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    function hash(IPermit2.PermitSingle memory permitSingle) internal pure returns (bytes32) {
        bytes32 permitHash = _hashPermitDetails(permitSingle.details);
        return
            keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permitSingle.spender, permitSingle.sigDeadline));
    }

    function _hashPermitDetails(IPermit2.PermitDetails memory details) private pure returns (bytes32) {
        return keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, details));
    }

    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );
}

// ------------------------------------------------------------------------
// Interface
// ------------------------------------------------------------------------

interface IPermit2 {
    struct PermitSingle {
        // the permit data for a single token alownce
        PermitDetails details;
        // address permissioned on the allowed tokens
        address spender;
        // deadline on the permit signature
        uint256 sigDeadline;
    }

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

    function permit(address owner, PermitSingle calldata permitSingle, bytes calldata signature) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
