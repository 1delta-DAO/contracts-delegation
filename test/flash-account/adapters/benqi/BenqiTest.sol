// SPDX-Licence-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {FlashAccount} from "@flash-account/FlashAccount.sol";
import {BenqiAdapter} from "@flash-account/Adapters/Lending/Benqi/BenqiAdapter.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {FlashAccountFactory} from "@flash-account/FlashAccountFactory.sol";
import {UpgradeableBeacon} from "@flash-account/proxy/Beacon.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UtilityAdapter} from "@flash-account/Adapters/UtilityAdapter.sol";
import {BaseLightAccount} from "@flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {console2 as console} from "forge-std/console2.sol";

contract BenqiTest is Test {
    using MessageHashUtils for bytes32;

    // Avalanche c-chain addresses
    address constant BENQI_COMPTROLLER = 0x486Af39519B4Dc9a7fCcd318217352830E8AD9b4;
    address constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address constant qiUSDC = 0xB715808a78F6041E46d61Cb123C9B4A27056AE9C;
    // test user
    uint256 userPrivateKey = 0x1de17a;
    address user;
    address owner = address(0x1);
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));

    EntryPoint public entryPoint;
    BenqiAdapter public benqiAdapter;
    UtilityAdapter public utilityAdapter;

    FlashAccount userFlashAccount;

    function setUp() public {
        // setup user
        user = vm.addr(userPrivateKey);

        // create a fork
        uint256 forkId = vm.createSelectFork(vm.envString("AVAX_RPC_URL")); // , 40840732);
        entryPoint = new EntryPoint();

        // Accounts
        FlashAccount flashAccountImplementation = new FlashAccount(entryPoint);
        UpgradeableBeacon beacon = new UpgradeableBeacon(owner, address(flashAccountImplementation));
        FlashAccountFactory flashAccountFactory = new FlashAccountFactory(owner, address(beacon), entryPoint);
        userFlashAccount = FlashAccount(payable(flashAccountFactory.createAccount(user, 1)));

        // adapters
        benqiAdapter = new BenqiAdapter();
        utilityAdapter = new UtilityAdapter();

        // deal some eth to the user and userAccount
        vm.deal(user, 1 ether);
        vm.deal(address(userFlashAccount), 1 ether);
    }

    function test_supplyAdapter() public {
        uint256 usdcAmount = 10000e6; // 10k USDC
        uint256 supplyAmount = 1000e6; // 1k USDC

        // deal some USDC to the account
        deal(USDC, address(userFlashAccount), usdcAmount);

        // gas limits
        uint128 verificationGasLimit = 1 << 24;
        uint128 callGasLimit = 1 << 24;
        uint128 maxPriorityFeePerGas = 1 << 8;
        uint128 maxFeePerGas = 1 << 8;

        // create an array of userOps that supplies usdc to benqi
        uint256 nonce = entryPoint.getNonce(address(userFlashAccount), 0);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](2);
        // transfer usdc to the adapter
        userOps[0] = PackedUserOperation({
            sender: address(userFlashAccount),
            nonce: nonce++,
            initCode: "",
            callData: abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(USDC),
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, address(benqiAdapter), supplyAmount)
            ),
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        userOps[0].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[0]).toEthSignedMessageHash())
        );
        // supply usdc to benqi
        userOps[1] = PackedUserOperation({
            sender: address(userFlashAccount),
            nonce: nonce,
            initCode: "",
            callData: abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                address(benqiAdapter),
                0,
                abi.encodeWithSelector(BenqiAdapter.supply.selector, qiUSDC, USDC, user)
            ),
            accountGasLimits: bytes32((uint256(verificationGasLimit) << 128) | callGasLimit),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(maxPriorityFeePerGas) << 128) | maxFeePerGas),
            paymasterAndData: "",
            signature: ""
        });
        userOps[1].signature = abi.encodePacked(
            BaseLightAccount.SignatureType.EOA,
            _sign(userPrivateKey, entryPoint.getUserOpHash(userOps[1]).toEthSignedMessageHash())
        );

        // init balances
        uint256 qiUsdcBalanceBefore = IERC20(qiUSDC).balanceOf(address(userFlashAccount));
        uint256 usdcBalanceBefore = IERC20(USDC).balanceOf(address(userFlashAccount));
        uint256 userBalanceBefore = IERC20(USDC).balanceOf(user);
        console.log("FlashAccount_qiUsdcBalance_before", qiUsdcBalanceBefore);
        console.log("FlashAccount_usdcBalance_before", usdcBalanceBefore);
        console.log("userBalance_before", userBalanceBefore);

        // send the userOps
        vm.prank(user);
        entryPoint.handleOps(userOps, BENEFICIARY);

        // check balances
        uint256 qiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(address(userFlashAccount));
        uint256 qiUsdcBalanceAdapterAfter = IERC20(qiUSDC).balanceOf(address(benqiAdapter));
        uint256 usdcBalanceAfter = IERC20(USDC).balanceOf(address(userFlashAccount));
        uint256 userBalanceAfter = IERC20(USDC).balanceOf(user);
        uint256 userQiUsdcBalanceAfter = IERC20(qiUSDC).balanceOf(user);

        console.log("FlashAccount_qiUsdcBalance_after", qiUsdcBalanceAfter);
        console.log("qiUsdcBalanceAdapter_after", qiUsdcBalanceAdapterAfter);
        console.log("FlashAccount_usdcBalance_after", usdcBalanceAfter);
        console.log("user_UsdcBalance_after", userBalanceAfter);
        console.log("user_qiUsdcBalance_after", userQiUsdcBalanceAfter);
    }

    function _sign(uint256 privateKey, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
