// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {FlashLoanExecuter} from "../../../../contracts/1delta/flash-account/FlashLoanExecuter.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";

import {IVault} from "./interfaces/IVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashLoanRecipient} from "./interfaces/IFlashLoanRecipient.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
import {ChainIds, TokenNames} from "../../chain/Lib.sol";

contract BalancerFlashLoanTests is FlashAccountBaseTest {
    using MessageHashUtils for bytes32;

    address public constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public USDC;

    event FlashLoan(IFlashLoanRecipient indexed recipient, IERC20 indexed token, uint256 amount, uint256 feeAmount);

    function setUp() public {
        _init(ChainIds.ETHEREUM);
        USDC = chain.getTokenAddress(TokenNames.USDC);
    }

    function testBalancerV2FlashLoanWithUserOp() public {
        // the flashLoanFeePercentage for BalancerV2 is 0% so we're not concerned with fee calculations
        uint256 amountToBorrow = 1e9;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow);

        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(userFlashAccount)), IERC20(USDC), amountToBorrow, 0);

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testBalancerV2FlashLoanDirect() public {
        // the flashLoanFeePercentage for BalancerV2 is 0% so we're not concerned with fee calculations
        uint256 amountToBorrow = 1e9;

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", BALANCER_VAULT, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        // flash loan args
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],bytes)", address(userFlashAccount), tokens, amounts, params
        );

        // Prepare the executeFlashLoan call
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, BALANCER_VAULT, flashLoanCall);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(IFlashLoanRecipient(address(userFlashAccount)), IERC20(USDC), amountToBorrow, 0);
        userFlashAccount.execute(address(userFlashAccount), 0, executeFlashLoanCall);
    }

    function prepareUserOp(uint256 amountToBorrow) private returns (PackedUserOperation memory op) {
        // Prepare flash loan call
        bytes memory flashLoanCall = _prepareCalldata(amountToBorrow);

        // Use executeFlashLoan instead of direct execute
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, BALANCER_VAULT, flashLoanCall);

        // Execute the flash loan call on the account itself
        bytes memory executeCall = abi.encodeWithSignature(
            "execute(address,uint256,bytes)", address(userFlashAccount), 0, executeFlashLoanCall
        );

        op = _getUnsignedOp(executeCall, entryPoint.getNonce(address(userFlashAccount), 0));

        op.signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(op).toEthSignedMessageHash())
        );
    }

    function _prepareCalldata(uint256 amountToBorrow) internal view returns (bytes memory) {
        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", BALANCER_VAULT, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        // flash loan args
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(USDC);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        return abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],bytes)", address(userFlashAccount), tokens, amounts, params
        );
    }
}
