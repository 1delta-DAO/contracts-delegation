// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CompoundV2Adapter} from "@flash-account/Adapters/Lending/CompoundV2/CompoundV2Adapter.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UtilityAdapter} from "@flash-account/Adapters/UtilityAdapter.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
// solhint-disable-next-line
import {console2 as console} from "forge-std/console2.sol";
import {Vm} from "forge-std/Vm.sol";

contract CompoundV2Test is FlashAccountBaseTest {
    using MessageHashUtils for bytes32;

    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);
    /**
     * An event emitted if the UserOperation "callData" reverted with non-zero length.
     * @param userOpHash   - The request unique identifier.
     * @param sender       - The sender of this request.
     * @param nonce        - The nonce used in the request.
     * @param revertReason - The return bytes from the (reverted) call to "callData".
     */
    event UserOperationRevertReason(bytes32 indexed userOpHash, address indexed sender, uint256 nonce, bytes revertReason);
    /***
     * An event emitted after each successful request.
     * @param userOpHash    - Unique identifier for the request (hash its entire content, except signature).
     * @param sender        - The account that generates this request.
     * @param paymaster     - If non-null, the paymaster that pays for this request.
     * @param nonce         - The nonce value from the request.
     * @param success       - True if the sender transaction succeeded, false if reverted.
     * @param actualGasCost - Actual amount paid (by account or paymaster) for this UserOperation.
     * @param actualGasUsed - Total gas used by this UserOperation (including preVerification, creation,
     *                        validation and execution).
     */
    event UserOperationEvent(
        bytes32 indexed userOpHash,
        address indexed sender,
        address indexed paymaster,
        uint256 nonce,
        bool success,
        uint256 actualGasCost,
        uint256 actualGasUsed
    );

    // Avalanche c-chain addresses
    address constant CompoundV2_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
    address constant qiAVAX = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

    CompoundV2Adapter internal compoundV2Adapter;
    UtilityAdapter internal utilityAdapter;

    function setUp() public override {
        super.setUp();

        // adapters
        compoundV2Adapter = new CompoundV2Adapter();
        utilityAdapter = new UtilityAdapter();
    }

    function testFlashAccountAdapter_Supply_Erc20_MultipleUserOps() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);
        // create an array of userOps that supplies usdc to CompoundV2
        uint256 nonce = entryPoint.getNonce(address(userFlashAccount), 0);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](2);
        // transfer usdc to the adapter
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(USDC),
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, address(compoundV2Adapter), supplyAmount)
            ),
            nonce++
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );
        // supply usdc to CompoundV2
        userOps[1] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(compoundV2Adapter),
                0,
                abi.encodeWithSelector(compoundV2Adapter.supply.selector, qiUSDC, USDC, user)
            ),
            nonce
        );
        userOps[1].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[1]).toEthSignedMessageHash())
        );

        // init balances
        uint256 userQiUsdcBalanceBefore = IERC20(qiUSDC).balanceOf(user);

        // send the userOps
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Mint(address(compoundV2Adapter), supplyAmount, supplyAmount);
        entryPoint.handleOps(userOps, BENEFICIARY);

        // check balances
        _checkBalances(usdcAmount, supplyAmount, userQiUsdcBalanceBefore);
    }

    function testFlashAccountAdapter_supplyAdapter_singleUserOp() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(compoundV2Adapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(compoundV2Adapter), supplyAmount);
        funcs[1] = abi.encodeWithSelector(compoundV2Adapter.supply.selector, qiUSDC, USDC, user);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature("executeBatch(address[],bytes[])", dests, funcs),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // init balances
        uint256 userQiUsdcBalanceBefore = IERC20(qiUSDC).balanceOf(user);

        // send the userOps
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Mint(address(compoundV2Adapter), supplyAmount, supplyAmount);
        entryPoint.handleOps(userOps, BENEFICIARY);

        // check balances
        _checkBalances(usdcAmount, supplyAmount, userQiUsdcBalanceBefore);
    }

    function testFlashAccountAdapter_supplyRevertsWhenTransferFails() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(compoundV2Adapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(compoundV2Adapter), ++usdcAmount);
        funcs[1] = abi.encodeWithSelector(compoundV2Adapter.supply.selector, qiUSDC, USDC, user);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature("executeBatch(address[],bytes[])", dests, funcs),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // init balances
        uint256 userQiUsdcBalanceBefore = IERC20(qiUSDC).balanceOf(user);

        // send the userOps
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit UserOperationRevertReason(entryPoint.getUserOpHash(userOps[0]), address(userFlashAccount), 0, "");
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testFlashAccountAdapter_repayAmount() public {
        // supply some usdc to the account
        _supply(10000e6, 1000e6);

        address[] memory dests = new address[](3);
        dests[0] = address(qiUSDC);
        dests[1] = address(USDC);
        dests[2] = address(compoundV2Adapter);
        bytes[] memory funcs = new bytes[](3);
        funcs[0] = abi.encodeWithSignature("borrow(uint256)", 100e6);
        funcs[1] = abi.encodeWithSelector(IERC20.transfer.selector, address(compoundV2Adapter), 100e6);
        funcs[2] = abi.encodeWithSelector(
            compoundV2Adapter.repay.selector,
            qiUSDC,
            USDC,
            address(userFlashAccount),
            address(userFlashAccount),
            100e6
        );

        // borrow some usdc and then repay it
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature("executeBatch(address[],bytes[])", dests, funcs),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // send the userOps
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Borrow(address(userFlashAccount), 100e6, 100e6, 100e6);
        vm.expectEmit(true, true, true, false);
        emit RepayBorrow(address(compoundV2Adapter), address(userFlashAccount), 100e6, 0, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testFlashAccountAdapter_supplyValue() public {
        uint256 avaxAmount = 0.5 ether;
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

        bytes memory callData = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            address(compoundV2Adapter),
            avaxAmount,
            abi.encodeWithSelector(compoundV2Adapter.supplyValue.selector, qiAVAX, address(userFlashAccount))
        );

        userOps[0] = _getUnsignedOp(callData, entryPoint.getNonce(address(userFlashAccount), 0));

        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        uint256 userQiAvaxBalanceBefore = IERC20(qiAVAX).balanceOf(address(userFlashAccount));

        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Mint(address(compoundV2Adapter), avaxAmount, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);

        uint256 userQiAvaxBalanceAfter = IERC20(qiAVAX).balanceOf(address(userFlashAccount));
        uint256 adapterQiAvaxBalanceAfter = IERC20(qiAVAX).balanceOf(address(compoundV2Adapter));

        assertGt(userQiAvaxBalanceAfter, userQiAvaxBalanceBefore, "User should receive qiAVAX tokens");
        assertEq(adapterQiAvaxBalanceAfter, 0, "Adapter should have transferred all qiAVAX tokens");
    }

    function testFlashAccountAdapter_supplyValue_revertOnZeroAmount() public {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

        bytes memory callData = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            address(compoundV2Adapter),
            0, // Zero AVAX
            abi.encodeWithSelector(compoundV2Adapter.supplyValue.selector, qiAVAX, user)
        );

        userOps[0] = _getUnsignedOp(callData, entryPoint.getNonce(address(userFlashAccount), 0));

        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit UserOperationRevertReason(entryPoint.getUserOpHash(userOps[0]), address(userFlashAccount), 0, "");
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testFlashAccountAdapter_repayValue() public {
        // supply to user
        testFlashAccountAdapter_supplyValue();

        bytes memory repayNativeCallData = abi.encodeWithSelector(
            compoundV2Adapter.repayValue.selector,
            qiAVAX,
            address(userFlashAccount),
            address(userFlashAccount),
            0.1 ether
        );

        address[] memory dests = new address[](2);
        dests[0] = address(qiAVAX);
        dests[1] = address(compoundV2Adapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSignature("borrow(uint256)", 0.1 ether);
        funcs[1] = repayNativeCallData;
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0.1 ether;

        // borrow and then repay native avax
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature("executeBatch(address[],uint256[],bytes[])", dests, values, funcs),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // send the userOps
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Borrow(address(userFlashAccount), 0.1 ether, 0.1 ether, 0.1 ether);
        vm.expectEmit(true, true, true, false);
        emit RepayBorrow(address(compoundV2Adapter), address(userFlashAccount), 0.1 ether, 0, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testApprovalMapping() public {
        // assert before supply
        assertEq(compoundV2Adapter.isApprovedAddress(USDC, qiUSDC), false);

        // supply
        _supply(10000e6, 1000e6);

        // assert after supply
        assertEq(compoundV2Adapter.isApprovedAddress(USDC, qiUSDC), true);
    }

    function testFlashAccountAdapter_supply_revertOnZeroRecipient() public {
        uint256 supplyAmount = 1000e6;

        // Create operation with zero address as recipient
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(compoundV2Adapter),
                0,
                abi.encodeWithSelector(compoundV2Adapter.supply.selector, qiUSDC, USDC, address(0))
            ),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // Should revert
        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit UserOperationRevertReason(entryPoint.getUserOpHash(userOps[0]), address(userFlashAccount), 0, "");
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testFlashAccountAdapter_supply_revertOnInvalidCToken() public {
        uint256 usdcAmount = 10000e6;
        uint256 supplyAmount = 1000e6;

        // Deal USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        // Transfer USDC to adapter
        vm.prank(address(userFlashAccount));
        IERC20(USDC).transfer(address(compoundV2Adapter), supplyAmount);

        // Create operation with invalid cToken address
        address invalidCToken = address(0x123);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(compoundV2Adapter),
                0,
                abi.encodeWithSelector(compoundV2Adapter.supply.selector, invalidCToken, USDC, user)
            ),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        bytes32 userOpHash = entryPoint.getUserOpHash(userOps[0]);
        userOps[0].signature = abi.encodePacked(BaseLightAccount.SignatureType.EOA, _sign(userPrivateKey, userOpHash.toEthSignedMessageHash()));

        // Should revert
        // Since we cannot expect a revert with reason, then we need to record all the logs and check if the userop call failed or not,
        vm.recordLogs();
        vm.prank(user);
        entryPoint.handleOps(userOps, BENEFICIARY);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool foundMatch;

        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length > 0 &&
                logs[i].topics[0] == keccak256("UserOperationEvent(bytes32,address,address,uint256,bool,uint256,uint256)")
            ) {
                if (logs[i].topics[1] == userOpHash) {
                    (, bool success, , ) = abi.decode(logs[i].data, (uint256, bool, uint256, uint256));
                    if (!success) {
                        foundMatch = true;
                        break;
                    }
                }
            }
        }
        assertTrue(foundMatch, "Userop didn't fail");
    }

    function testFlashAccountAdapter_multicall_transfer_funds() public {
        vm.deal(address(compoundV2Adapter), 1 ether);
        address[] memory dests = new address[](1);
        dests[0] = address(address(0x2));
        bytes[] memory funcs = new bytes[](1);
        funcs[0] = "";
        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        compoundV2Adapter.multicall(dests, values, funcs);

        assertEq(address(0x2).balance, 1 ether);
    }

    // Helpers

    function _supply(uint256 usdcAmount, uint256 supplyAmount) internal {
        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(compoundV2Adapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(compoundV2Adapter), supplyAmount);
        funcs[1] = abi.encodeWithSelector(compoundV2Adapter.supply.selector, qiUSDC, USDC, address(userFlashAccount));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature("executeBatch(address[],bytes[])", dests, funcs),
            entryPoint.getNonce(address(userFlashAccount), 0)
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        // send the userOps
        vm.prank(user);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function _checkBalances(uint256 usdcAmount, uint256 supplyAmount, uint256 userQiUsdcBalanceBefore) internal view {
        uint256 qiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(address(userFlashAccount));
        uint256 qiUsdcBalanceAdapterAfter = IERC20(qiUSDC).balanceOf(address(compoundV2Adapter));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(userFlashAccount));
        uint256 userQiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(user);

        assertEq(qiUsdcBalanceAfter, 0);
        assertEq(usdcBalanceAfter, usdcAmount - supplyAmount);
        assertEq(qiUsdcBalanceAdapterAfter, 0);
        assertGt(userQiUsdcBalanceAfter, userQiUsdcBalanceBefore);
    }
}
