// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainIds, TokenNames} from "../../chain/Lib.sol";

// Interface for Balancer V3 Vault
interface IVaultMain {
    function unlock(bytes calldata data) external;
    function sendTo(IERC20 token, address to, uint256 amount) external;
    function settle(IERC20 token, uint256 amount) external;
}

contract BalancerV3FlashLoanTests is FlashAccountBaseTest {
    using MessageHashUtils for bytes32;

    event Transfer(address indexed from, address indexed to, uint256 value);

    address internal BALANCER_V3_VAULT;
    address internal USDC;

    function setUp() public {
        _init(ChainIds.ETHEREUM);

        BALANCER_V3_VAULT = chain.getTokenAddress(TokenNames.BALANCER_V3_VAULT);
        USDC = chain.getTokenAddress(TokenNames.USDC);
    }

    function testRevertIfNotInExecution_cancun() public {
        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", user, 1e6);

        bytes memory params = abi.encode(dests, values, calls);

        vm.prank(user);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        userFlashAccount.receiveFlashLoan(params);
    }

    function testBalancerV3FlashLoanDirect_cancun() public {
        uint256 amountToBorrow = 1e9;
        // calldata
        bytes memory unlockCall = _prepareCalldata(amountToBorrow);

        // Prepare the executeFlashLoan call
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashAccount.executeFlashLoan.selector, BALANCER_V3_VAULT, unlockCall);

        // Execute the flash loan
        vm.prank(user);
        // flash loan transfer event
        vm.expectEmit(true, true, true, true);
        emit Transfer(BALANCER_V3_VAULT, address(userFlashAccount), amountToBorrow);
        // repay the loan event
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(userFlashAccount), BALANCER_V3_VAULT, amountToBorrow);
        userFlashAccount.execute(address(userFlashAccount), 0, executeFlashLoanCall);
    }

    function testBalancerV3FlashLoanWithUserOp_cancun() public {
        uint256 amountToBorrow = 1e9;

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow);

        // flash loan transfer event
        vm.expectEmit(true, true, true, true);
        emit Transfer(BALANCER_V3_VAULT, address(userFlashAccount), amountToBorrow);
        // repay the loan event
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(userFlashAccount), BALANCER_V3_VAULT, amountToBorrow);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function prepareUserOp(uint256 loanAmount) private returns (PackedUserOperation memory op) {
        // prepare the calldata
        bytes memory unlockCall = _prepareCalldata(loanAmount);

        // Use executeFlashLoan instead of direct execute
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashAccount.executeFlashLoan.selector, BALANCER_V3_VAULT, unlockCall);

        // Execute the flash loan call on the account itself
        bytes memory executeCall = abi.encodeWithSignature(
            "execute(address,uint256,bytes)", address(userFlashAccount), 0, executeFlashLoanCall
        );

        // prepare the user op
        op = _getUnsignedOp(executeCall, entryPoint.getNonce(address(userFlashAccount), 0));
        // sign the user op
        op.signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(op).toEthSignedMessageHash())
        );
    }

    function _prepareCalldata(uint256 loanAmount) internal view returns (bytes memory unlockCall) {
        address[] memory dests = new address[](3);
        dests[0] = BALANCER_V3_VAULT;
        dests[1] = USDC;
        dests[2] = BALANCER_V3_VAULT;
        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        bytes[] memory calls = new bytes[](3);
        // flash loan call
        calls[0] =
            abi.encodeWithSignature("sendTo(address,address,uint256)", USDC, address(userFlashAccount), loanAmount);
        // repay the loan
        calls[1] = abi.encodeWithSignature("transfer(address,uint256)", BALANCER_V3_VAULT, loanAmount);
        // settle the loan
        calls[2] = abi.encodeWithSignature("settle(address,uint256)", USDC, loanAmount);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory callbackData = abi.encodeWithSignature("receiveFlashLoan(bytes)", params);

        unlockCall = abi.encodeWithSelector(IVaultMain.unlock.selector, callbackData);
    }
}
