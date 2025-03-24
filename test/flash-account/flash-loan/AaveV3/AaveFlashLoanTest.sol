// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {FlashLoanExecuter} from "../../../../contracts/1delta/flash-account/FlashLoanExecuter.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainIds, TokenNames} from "../../chain/Lib.sol";
import {IPool, DataTypes} from "./interfaces/IPool.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract AaveFlashLoanTest is FlashAccountBaseTest {
    using Math for uint256;
    using MessageHashUtils for bytes32;

    address internal AAVEV3_POOL;
    address internal USDC;

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
        _init(ChainIds.ETHEREUM);

        AAVEV3_POOL = chain.getTokenAddress(TokenNames.AaveV3_Pool);
        USDC = chain.getTokenAddress(TokenNames.USDC);
    }

    function test_flashAccount_FlashLoan_AaveV3_RevertIfNotInExecution() public {
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
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        userFlashAccount.executeOperation(USDC, 1e9, 0, 0x120D2fDdC53467479570B2E7870d6d7A80b0f050, params);
    }

    function test_flashAccount_FlashLoan_AaveV3_RevertIfDirectlyCallPoolForLoan() public {
        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), 1e6);
        bytes memory params = abi.encode(dests, values, calls);

        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        IPool(AAVEV3_POOL).flashLoanSimple(address(userFlashAccount), USDC, 1e9, params, 0);
    }

    function test_flashAccount_FlashLoan_AaveV3_DirectCall() public {
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(userFlashAccount), aavePremium);

        // console.log("totalDebt", totalDebt);

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoanSimple(address,address,uint256,bytes,uint16)",
            address(userFlashAccount),
            USDC,
            amountToBorrow,
            params,
            0
        );

        // Use executeFlashLoan instead of direct execute
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, AAVEV3_POOL, flashLoanCall);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(
            address(userFlashAccount),
            address(userFlashAccount),
            USDC,
            amountToBorrow,
            DataTypes.InterestRateMode.NONE,
            aavePremium,
            uint16(0)
        );

        userFlashAccount.execute(address(userFlashAccount), 0, executeFlashLoanCall);
    }

    function testAaveV3FlashLoanWithUserOp() public {
        uint128 flashLoanPremiumTotal = IPool(AAVEV3_POOL).FLASHLOAN_PREMIUM_TOTAL();
        uint256 amountToBorrow = 1e9;
        uint256 aavePremium = percentMul(amountToBorrow, flashLoanPremiumTotal);
        uint256 totalDebt = amountToBorrow + aavePremium;

        // Transfer USDC to account
        vm.prank(0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341);
        IERC20(USDC).transfer(address(userFlashAccount), aavePremium);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow, totalDebt);

        vm.expectEmit(true, true, true, true);
        emit FlashLoan(
            address(userFlashAccount),
            address(userFlashAccount),
            USDC,
            amountToBorrow,
            DataTypes.InterestRateMode.NONE,
            aavePremium,
            uint16(0)
        );

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function prepareUserOp(uint256 amountToBorrow, uint256 totalDebt) private returns (PackedUserOperation memory op) {
        bytes memory flashLoanCall = _prepareCalldata(amountToBorrow, totalDebt);

        // Use executeFlashLoan instead of direct execute
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, AAVEV3_POOL, flashLoanCall);

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

    function _prepareCalldata(uint256 amountToBorrow, uint256 totalDebt)
        internal
        view
        returns (bytes memory flashLoanCall)
    {
        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", AAVEV3_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        flashLoanCall = abi.encodeWithSignature(
            "flashLoanSimple(address,address,uint256,bytes,uint16)",
            address(userFlashAccount),
            USDC,
            amountToBorrow,
            params,
            0
        );
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
