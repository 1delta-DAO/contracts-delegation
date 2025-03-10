// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BenqiAdapter} from "@flash-account/Adapters/Lending/Benqi/BenqiAdapter.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UtilityAdapter} from "@flash-account/Adapters/UtilityAdapter.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";

contract BenqiTest is FlashAccountBaseTest {
    using MessageHashUtils for bytes32;

    event Mint(address minter, uint256 mintAmount, uint256 mintTokens);
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);
    event UserOperationRevertReason(bytes32 indexed userOpHash, address indexed sender, uint256 nonce, bytes revertReason);

    // Avalanche c-chain addresses
    address constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
    address constant qiAVAX = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

    BenqiAdapter internal benqiAdapter;
    UtilityAdapter internal utilityAdapter;

    function setUp() public override {
        super.setUp();

        // adapters
        benqiAdapter = new BenqiAdapter();
        utilityAdapter = new UtilityAdapter();
    }

    function test_supplyAdapter_multipleUserOps() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);
        // create an array of userOps that supplies usdc to benqi
        uint256 nonce = entryPoint.getNonce(address(userFlashAccount), 0);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](2);
        // transfer usdc to the adapter
        userOps[0] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(USDC),
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), supplyAmount)
            ),
            nonce++
        );
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );
        // supply usdc to benqi
        userOps[1] = _getUnsignedOp(
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(benqiAdapter),
                0,
                abi.encodeWithSelector(BenqiAdapter.supply.selector, qiUSDC, USDC, user)
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
        emit Mint(address(benqiAdapter), supplyAmount, supplyAmount);
        entryPoint.handleOps(userOps, BENEFICIARY);

        // check balances
        _checkBalances(usdcAmount, supplyAmount, userQiUsdcBalanceBefore);
    }

    function test_supplyAdapter_singleUserOp() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(benqiAdapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), supplyAmount);
        funcs[1] = abi.encodeWithSelector(BenqiAdapter.supply.selector, qiUSDC, USDC, user);

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
        emit Mint(address(benqiAdapter), supplyAmount, supplyAmount);
        entryPoint.handleOps(userOps, BENEFICIARY);

        // check balances
        _checkBalances(usdcAmount, supplyAmount, userQiUsdcBalanceBefore);
    }

    function test_supplyRevertsWhenTransferFails() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(benqiAdapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), ++usdcAmount);
        funcs[1] = abi.encodeWithSelector(BenqiAdapter.supply.selector, qiUSDC, USDC, user);

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

    function testRepay() public {
        // supply some usdc to the account
        _supply(10000e6, 1000e6);

        address[] memory dests = new address[](3);
        dests[0] = address(qiUSDC);
        dests[1] = address(USDC);
        dests[2] = address(benqiAdapter);
        bytes[] memory funcs = new bytes[](3);
        funcs[0] = abi.encodeWithSignature("borrow(uint256)", 100e6);
        funcs[1] = abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), 100e6);
        funcs[2] = abi.encodeWithSelector(BenqiAdapter.repay.selector, qiUSDC, USDC, address(userFlashAccount), address(userFlashAccount));

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
        emit RepayBorrow(address(benqiAdapter), address(userFlashAccount), 100e6, 0, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function test_supplyNative() public {
        uint256 avaxAmount = 0.5 ether;
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

        bytes memory callData = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            address(benqiAdapter),
            avaxAmount,
            abi.encodeWithSelector(BenqiAdapter.supplyNative.selector, qiAVAX, user)
        );

        userOps[0] = _getUnsignedOp(callData, entryPoint.getNonce(address(userFlashAccount), 0));

        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );

        uint256 userQiAvaxBalanceBefore = IERC20(qiAVAX).balanceOf(user);

        vm.prank(user);
        vm.expectEmit(true, true, false, false);
        emit Mint(address(benqiAdapter), avaxAmount, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);

        uint256 userQiAvaxBalanceAfter = IERC20(qiAVAX).balanceOf(user);
        uint256 adapterQiAvaxBalanceAfter = IERC20(qiAVAX).balanceOf(address(benqiAdapter));

        assertGt(userQiAvaxBalanceAfter, userQiAvaxBalanceBefore, "User should receive qiAVAX tokens");
        assertEq(adapterQiAvaxBalanceAfter, 0, "Adapter should have transferred all qiAVAX tokens");
    }

    function test_supplyNative_revertOnZeroAmount() public {
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);

        bytes memory callData = abi.encodeWithSignature(
            "execute(address,uint256,bytes)",
            address(benqiAdapter),
            0, // Zero AVAX
            abi.encodeWithSelector(BenqiAdapter.supplyNative.selector, qiAVAX, user)
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

    function _supply(uint256 usdcAmount, uint256 supplyAmount) internal {
        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        address[] memory dests = new address[](2);
        dests[0] = address(USDC);
        dests[1] = address(benqiAdapter);
        bytes[] memory funcs = new bytes[](2);
        funcs[0] = abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), supplyAmount);
        funcs[1] = abi.encodeWithSelector(BenqiAdapter.supply.selector, qiUSDC, USDC, address(userFlashAccount));

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

    function _checkBalances(uint256 usdcAmount, uint256 supplyAmount, uint256 userQiUsdcBalanceBefore) internal {
        uint256 qiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(address(userFlashAccount));
        uint256 qiUsdcBalanceAdapterAfter = IERC20(qiUSDC).balanceOf(address(benqiAdapter));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(userFlashAccount));
        uint256 userQiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(user);

        assertEq(qiUsdcBalanceAfter, 0);
        assertEq(usdcBalanceAfter, usdcAmount - supplyAmount);
        assertEq(qiUsdcBalanceAdapterAfter, 0);
        assertGt(userQiUsdcBalanceAfter, userQiUsdcBalanceBefore);
    }
}
