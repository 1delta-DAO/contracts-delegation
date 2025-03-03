// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {FlashAccountBase} from "@flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CTokenSignatures} from "@flash-account/Lenders/Benqi/CTokenSignatures.sol";
import {console2 as console} from "forge-std/console2.sol";
import {ILendingProvider} from "@flash-account/interfaces/ILendingProvider.sol";

contract TestBenqi is Test, CTokenSignatures {
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));

    address public constant AAVEV3_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    address public constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address public constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
    address public constant qiAVAX = 0x5C0401e81Bc07Ca70fAD469b451682c0d747Ef1c;

    uint256 public chainFork;

    address public eoaAddress;
    address public beaconOwner;
    address public initialAccountImplementation;

    FlashAccount public account;
    FlashAccount public beaconOwnerAccount;
    IEntryPoint public entryPoint;
    FlashAccountFactory public factory;

    UpgradeableBeacon public accountBeacon;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
    event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    function setUp() public {
        // Initialize a mainnet fork
        string memory rpcUrl = vm.envString("AVAX_RPC_URL");
        chainFork = vm.createSelectFork(rpcUrl); // , 40840732);

        eoaAddress = vm.addr(EOA_PRIVATE_KEY);
        beaconOwner = vm.addr(BEACON_OWNER_PRIVATE_KEY);

        entryPoint = new EntryPoint();
        FlashAccount implementation = new FlashAccount(entryPoint);
        initialAccountImplementation = address(implementation);

        accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
        factory = new FlashAccountFactory(beaconOwner, address(accountBeacon), entryPoint);

        account = FlashAccount(payable(factory.createAccount(eoaAddress, 1)));
        beaconOwnerAccount = FlashAccount(payable(factory.createAccount(beaconOwner, 1)));

        vm.deal(address(account), 1 << 128);
        vm.deal(eoaAddress, 1 << 128);
    }

    function testSupplyDirect() public {
        _supplyUsdcDirect(1e9);
    }

    function testSupplyUserOp() public {
        _supplyUsdcUserOp(1e9);
    }

    function testBorrowDirect() public {
        // lend some usdc to qiUSDC
        _supplyUsdcDirect(1e9);
        // borrow usdc from qiUSDC
        _borrowUsdcDirect(1e8);
    }

    function testBorrowUserOp() public {
        // lend some usdc to qiUSDC
        _supplyUsdcUserOp(1e9);
        // borrow usdc from qiUSDC
        _borrowUsdcUserOp(1e8);
    }

    // function testWithdraw() public {
    //     _supplyUsdc(1e9);
    //     _withdrawUsdc(1e9);
    // }

    // function testWithdrawAll() public {
    //     _supplyUsdc(1e9);
    //     vm.warp(block.timestamp + 10000);
    //     (bool success, bytes memory data) = qiUSDC.call(abi.encodeWithSelector(CTOKEN_BALANCE_OF_UNDERLYING_SELECTOR, address(account)));
    //     uint256 balance = abi.decode(data, (uint256));
    //     _withdrawUsdc(balance);
    //     vm.assertGt(balance, 1e9);
    //     // console.log("balance", balance);
    // }

    // function testRepay() public {
    //     // lend some usdc to qiUSDC
    //     _supplyUsdc(1e9);
    //     // borrow usdc from qiUSDC
    //     _borrowUsdc(1e8);
    //     // repay usdc to qiUSDC
    //     _repayUsdc(1e8);
    // }

    function _supplyUsdcDirect(uint256 amount) private {
        deal(USDC, address(account), amount);

        // supply to Benqi
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: address(account),
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: amount,
            params: ""
        });

        bytes memory callData = abi.encodeWithSelector(FlashAccount.supply.selector, params);
        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, false);
        emit ILendingProvider.Supplied(address(account), USDC, amount);
        account.execute(address(account), 0, callData);
    }

    function _supplyUsdcUserOp(uint256 amount) private {
        deal(USDC, address(account), amount);

        // supply to Benqi
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: address(account),
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: amount,
            params: ""
        });

        bytes memory supplyCallData = abi.encodeWithSelector(FlashAccount.supply.selector, params);
        bytes memory executeCall = abi.encodeWithSignature("execute(address,uint256,bytes)", address(account), 0, supplyCallData);

        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account),
            nonce: entryPoint.getNonce(address(account), 0),
            initCode: "",
            callData: executeCall,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        userOp.signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(EOA_PRIVATE_KEY, entryPoint.getUserOpHash(userOp).toEthSignedMessageHash())
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        entryPoint.handleOps(ops, BENEFICIARY);

        vm.stopPrank();
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _borrowUsdcDirect(uint256 amount) private {
        uint256 initBalance = IERC20(USDC).balanceOf(address(account));
        // borrow from Benqi
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: address(account),
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: amount,
            params: ""
        });

        bytes memory callData = abi.encodeWithSelector(FlashAccount.borrow.selector, params);
        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, false);
        emit ILendingProvider.Borrowed(address(account), USDC, amount);
        account.execute(address(account), 0, callData);

        uint256 balance = IERC20(USDC).balanceOf(address(account));
        assertEq(balance, initBalance + amount);
    }

    function _borrowUsdcUserOp(uint256 amount) private {
        deal(USDC, address(account), amount);

        // supply to Benqi
        ILendingProvider.LendingParams memory params = ILendingProvider.LendingParams({
            caller: address(account),
            lender: BENQI_COMPTROLLER,
            asset: USDC,
            collateralToken: qiUSDC,
            amount: amount,
            params: ""
        });

        bytes memory borrowCallData = abi.encodeWithSelector(FlashAccount.borrow.selector, params);
        bytes memory executeCall = abi.encodeWithSignature("execute(address,uint256,bytes)", address(account), 0, borrowCallData);

        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account),
            nonce: entryPoint.getNonce(address(account), 0),
            initCode: "",
            callData: executeCall,
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        userOp.signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(EOA_PRIVATE_KEY, entryPoint.getUserOpHash(userOp).toEthSignedMessageHash())
        );

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        entryPoint.handleOps(ops, BENEFICIARY);

        vm.stopPrank();
    }

    // function _repayUsdc(uint256 amount) private {
    //     vm.startPrank(eoaAddress);
    //     vm.expectEmit(true, true, false, false);
    //     emit RepayBorrow(address(account), address(account), amount, 0, 0);
    //     account.benqiRepay(qiUSDC, amount);
    //     vm.stopPrank();
    // }

    // function _withdrawUsdc(uint256 amount) private {
    //     vm.startPrank(eoaAddress);
    //     vm.expectEmit(true, true, false, false);
    //     emit Redeem(address(account), amount, 0);
    //     account.benqiWithdrawUnderlying(qiUSDC, amount);
    //     vm.stopPrank();
    // }
}
