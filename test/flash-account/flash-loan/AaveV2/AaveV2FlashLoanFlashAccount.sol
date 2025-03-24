// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {FlashLoanExecuter} from "../../../../contracts/1delta/flash-account/FlashLoanExecuter.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainIds, TokenNames} from "../../chain/Lib.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract AaveV2FlashLoanFlashAccount is FlashAccountBaseTest {
    using Math for uint256;
    using MessageHashUtils for bytes32;

    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 premium,
        uint16 referralCode
    );

    address internal AAVE_V2_LENDING_POOL;
    address internal USDC;

    function setUp() public {
        _init(ChainIds.ETHEREUM);

        AAVE_V2_LENDING_POOL = chain.getTokenAddress(TokenNames.AAVE_V2_LENDING_POOL);
        USDC = chain.getTokenAddress(TokenNames.USDC);
    }

    function test_flashAccount_FlashLoan_AaveV2_RevertIfNotInExecution() public {
        address sender = address(0x0a1);
        vm.deal(sender, 1e6);

        address[] memory assets = new address[](1);
        assets[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        uint256[] memory premiums = new uint256[](1);
        premiums[0] = 0;

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", sender, 1e6);

        bytes memory params = abi.encode(dests, values, calls);

        vm.prank(sender);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        userFlashAccount.executeOperation(assets, amounts, premiums, sender, params);
    }

    function test_flashAccount_FlashLoan_AaveV2_RevertIfDirectlyCallLendingPoolForLoan() public {
        address[] memory assets = new address[](1);
        assets[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e6;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // no debt

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("transfer(address,uint256)", address(this), 1e6);

        bytes memory params = abi.encode(dests, values, calls);

        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        AAVE_V2_LENDING_POOL.call(
            abi.encodeWithSignature(
                "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)",
                address(userFlashAccount),
                assets,
                amounts,
                modes,
                address(userFlashAccount),
                params,
                0
            )
        );
    }

    function test_flashAccount_FlashLoan_AaveV2_RevertIfDirectCall() public {
        uint256 amountToBorrow = 1000e6;
        uint256 premium = _getPremiumAmount(amountToBorrow);

        deal(USDC, address(userFlashAccount), premium);

        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        // amount to repay the loan
        uint256 totalDebt = amountToBorrow + premium;

        calls[0] = abi.encodeWithSelector(IERC20.approve.selector, AAVE_V2_LENDING_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        address[] memory assets = new address[](1);
        assets[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)",
            address(userFlashAccount),
            assets,
            amounts,
            modes,
            address(userFlashAccount),
            params,
            uint16(0)
        );

        vm.prank(user);
        vm.expectRevert(bytes4(0x0f2e5b6c)); // Locked()
        userFlashAccount.execute(AAVE_V2_LENDING_POOL, 0, flashLoanCall);
    }

    function test_flashAccount_FlashLoan_AaveV2_DirectCall() public {
        uint256 amountToBorrow = 1000e6;
        uint256 premium = _getPremiumAmount(amountToBorrow);

        deal(USDC, address(userFlashAccount), premium);

        // prepare the repay calldata
        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSelector(IERC20.approve.selector, AAVE_V2_LENDING_POOL, amountToBorrow + premium);

        bytes memory params = abi.encode(dests, values, calls);

        // prepare the flash loan call data
        address[] memory assets = new address[](1);
        assets[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToBorrow;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory flashLoanCall = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)",
            address(userFlashAccount),
            assets,
            amounts,
            modes,
            address(userFlashAccount),
            params,
            uint16(0)
        );

        // execute flash loan call with the flash account
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, AAVE_V2_LENDING_POOL, flashLoanCall);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(address(userFlashAccount), address(userFlashAccount), USDC, amountToBorrow, premium, 0);

        userFlashAccount.execute(address(userFlashAccount), 0, executeFlashLoanCall);
    }

    function testAaveV2FlashLoanWithUserOp() public {
        uint256 amountToBorrow = 1000e6;
        uint256 premium = _getPremiumAmount(amountToBorrow);

        deal(USDC, address(userFlashAccount), premium);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow);

        vm.prank(user);
        vm.expectEmit(true, true, true, true);
        emit FlashLoan(address(userFlashAccount), address(userFlashAccount), USDC, amountToBorrow, premium, 0);
        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function prepareUserOp(uint256 loanAmount) private returns (PackedUserOperation memory op) {
        // prepare the flash loan calldata
        bytes memory flashLoanCall = _prepareCalldata(loanAmount);

        // prepare the executeFlashLoan call (instead of normal execute)
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashLoanExecuter.executeFlashLoan.selector, AAVE_V2_LENDING_POOL, flashLoanCall);

        // prepare the execute call to the account itself
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

    function _prepareCalldata(uint256 loanAmount) internal returns (bytes memory flcall) {
        address[] memory dests = new address[](1);
        dests[0] = USDC;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calls = new bytes[](1);
        // repay the loan
        uint256 totalDebt = loanAmount + _getPremiumAmount(loanAmount);

        calls[0] = abi.encodeWithSelector(IERC20.approve.selector, AAVE_V2_LENDING_POOL, totalDebt);

        bytes memory params = abi.encode(dests, values, calls);

        address[] memory assets = new address[](1);
        assets[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loanAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        flcall = abi.encodeWithSignature(
            "flashLoan(address,address[],uint256[],uint256[],address,bytes,uint16)",
            address(userFlashAccount),
            assets,
            amounts,
            modes,
            address(userFlashAccount),
            params,
            uint16(0)
        );
    }

    function _getPremiumAmount(uint256 loanAmount) internal view returns (uint256 amount) {
        (bool success, bytes memory data) =
            AAVE_V2_LENDING_POOL.staticcall(abi.encodeWithSignature("FLASHLOAN_PREMIUM_TOTAL()"));
        require(success, "FLASHLOAN_PREMIUM_TOTAL() call failed");
        uint256 premium = abi.decode(data, (uint256));
        amount = loanAmount.mulDiv(premium, 10000);
    }
}
