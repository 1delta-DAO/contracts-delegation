// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {FlashAccount} from "../../../../contracts/1delta/flash-account/FlashAccount.sol";
import {BaseLightAccount} from "../../../../contracts/1delta/flash-account/common/BaseLightAccount.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FlashAccountBaseTest} from "../../FlashAccountBaseTest.sol";
import {ChainIds, TokenNames} from "../../chain/Lib.sol";

contract MorphoFlashLoanTests is FlashAccountBaseTest {
    using MessageHashUtils for bytes32;

    address public constant MORPHO_POOL = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public USDC;

    event FlashLoan(address indexed caller, address indexed token, uint256 assets);

    function setUp() public {
        _init(ChainIds.ETHEREUM);
        USDC = chain.getTokenAddress(TokenNames.USDC);
    }

    function testMorphoFlashLoanWithUserOp() public {
        uint256 amountToBorrow = IERC20(USDC).balanceOf(address(MORPHO_POOL));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = prepareUserOp(amountToBorrow);

        vm.expectEmit(true, true, true, false);
        emit FlashLoan(address(userFlashAccount), USDC, amountToBorrow);

        entryPoint.handleOps(userOps, BENEFICIARY);
    }

    function testMorphoFlashLoanDirect() public {
        uint256 amountToBorrow = IERC20(USDC).balanceOf(address(MORPHO_POOL));

        address[] memory dests = new address[](1);
        dests[0] = USDC;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_POOL, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        bytes memory flashLoanCall =
            abi.encodeWithSignature("flashLoan(address,uint256,bytes)", USDC, amountToBorrow, params);

        // Prepare the executeFlashLoan call
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashAccount.executeFlashLoan.selector, MORPHO_POOL, flashLoanCall);

        vm.prank(user);
        vm.expectEmit(true, true, true, false);
        emit FlashLoan(address(userFlashAccount), USDC, amountToBorrow);
        userFlashAccount.execute(address(userFlashAccount), 0, executeFlashLoanCall);
    }

    function prepareUserOp(uint256 amountToBorrow) private returns (PackedUserOperation memory op) {
        // Prepare flash loan call
        bytes memory flashLoanCall = _prepareCalldata(amountToBorrow);

        // Use executeFlashLoan instead of direct execute
        bytes memory executeFlashLoanCall =
            abi.encodeWithSelector(FlashAccount.executeFlashLoan.selector, MORPHO_POOL, flashLoanCall);

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
        calls[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_POOL, amountToBorrow);

        bytes memory params = abi.encode(dests, values, calls);

        return abi.encodeWithSignature("flashLoan(address,uint256,bytes)", USDC, amountToBorrow, params);
    }
}
