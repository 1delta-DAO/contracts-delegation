// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableBeacon} from "../../../../contracts/1delta/flash-account//proxy/Beacon.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {FlashAccountBase} from "../../../../contracts/1delta/flash-account/FlashAccountBase.sol";
import {FlashAccountFactory} from "../../../../contracts/1delta/flash-account/FlashAccountFactory.sol";
import {Owner} from "../../FlashAccount.t.sol";

import {IPool, DataTypes} from "./interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveFlashLoanTest is Test {
    using stdStorage for StdStorage;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    uint256 public constant EOA_PRIVATE_KEY = 1;
    uint256 public constant BEACON_OWNER_PRIVATE_KEY = 2;
    address payable public constant BENEFICIARY = payable(address(0xbe9ef1c1a2ee));
    address public constant AAVEV3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 internal constant _MESSAGE_TYPEHASH = keccak256("LightAccountMessage(bytes message)");
    uint256 public mainnetFork;

    address public eoaAddress;
    address public beaconOwner;
    address public initialAccountImplementation;

    FlashAccount public account;
    FlashAccount public beaconOwnerAccount;
    EntryPoint public entryPoint;
    FlashAccountFactory public factory;

    UpgradeableBeacon public accountBeacon;

    Owner public contractOwner;

    event FlashLoan(
        address indexed target,
        address initiator,
        address indexed asset,
        uint256 amount,
        DataTypes.InterestRateMode interestRateMode,
        uint256 premium,
        uint16 indexed referralCode
    );

    function setUp() public {
        // Initialize a mainnet fork
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createSelectFork(rpcUrl);

        eoaAddress = vm.addr(EOA_PRIVATE_KEY);
        beaconOwner = vm.addr(BEACON_OWNER_PRIVATE_KEY);

        entryPoint = new EntryPoint();
        FlashAccount implementation = new FlashAccount(entryPoint);
        initialAccountImplementation = address(implementation);

        accountBeacon = new UpgradeableBeacon(beaconOwner, initialAccountImplementation);
        factory = new FlashAccountFactory(beaconOwner, address(accountBeacon), entryPoint);

        account = factory.createAccount(eoaAddress, 1);
        beaconOwnerAccount = factory.createAccount(beaconOwner, 1);

        vm.deal(address(account), 1 << 128);
        vm.deal(eoaAddress, 1 << 128);
        contractOwner = new Owner();
    }

    function testRevertIfNotInExecution() public {
        address sender = address(0x0a1);
        vm.deal(sender, 1e6);

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", sender, 1e6);

        bytes memory params = abi.encode(dests, values, calls);

        vm.prank(sender);
        // vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        vm.expectRevert();
        account.executeOperation(USDC, 1e9, 0, 0x120D2fDdC53467479570B2E7870d6d7A80b0f050, params);
    }

    function testRevertIfDirectlyCallPoolForLoan() public {
        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), 1e6);
        bytes memory params = abi.encode(dests, values, calls);

        // vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        vm.expectRevert();
        IPool(AAVEV3_POOL).flashLoanSimple(address(account), USDC, 1e9, params, 0);
    }

    function testFlashLoanDirect() public {
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(account), aavePremium);

        console.log("totalDebt", totalDebt);

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoanSimple(address,address,uint256,bytes,uint16)", address(account), USDC, amountToBorrow, params, 0
        );

        vm.prank(eoaAddress);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(
            address(account),
            address(account),
            USDC,
            amountToBorrow,
            DataTypes.InterestRateMode.NONE,
            aavePremium,
            uint16(0)
        );
        account.execute(AAVEV3_POOL, 0, flashLoanCall);
    }

    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    // Half percentage factor (50.00%)
    uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

    /**
     * @notice Executes a percentage multiplication
     * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
     * @param value The value of which the percentage needs to be calculated
     * @param percentage The percentage of the value to be calculated
     * @return result value percentmul percentage
     */
    function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
        // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
        assembly {
            if iszero(or(iszero(percentage), iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage))))) {
                revert(0, 0)
            }

            result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
        }
    }
}
