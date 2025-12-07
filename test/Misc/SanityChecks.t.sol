// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IComposerLike} from "test/shared/composers/IComposerLike.sol";
import {ComposerPlugin} from "test/shared/composers/ComposerPlugin.sol";
import {Chains} from "test/data/LenderRegistry.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {console} from "forge-std/console.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";

contract SanityChecks is Test {
    IComposerLike composer;

    function setUp() public {
        composer = ComposerPlugin.getComposer(Chains.ETHEREUM_MAINNET);
    }

    function test_sanity_calldata_length(uint256 additionalLength) public {
        bytes memory cd = CalldataLib.encodeSweep(0x1234567890123456789012345678901234567890, address(this), 0, SweepType.VALIDATE);
        cd = abi.encodeWithSelector(composer.deltaCompose.selector, cd);
        assembly {
            mstore(add(cd, 0x44), add(mload(cd), additionalLength))
        }

        console.logBytes(cd);

        vm.expectRevert();
        (bool success, bytes memory returnData) = address(composer).call(cd);
    }

    function test_sanity_externalCall_to_EOA() public {
        address eoa = address(0x1De17A0000000000000000000000000000000000);
        uint256 ethAmount = 1 ether;
        uint256 initialEoaBalance = eoa.balance;

        deal(address(composer), ethAmount);
        uint256 composerInitialBalance = address(composer).balance;

        bytes memory cd = CalldataLib.encodeSweep(0x1De17A0000000000000000000000000000000000, address(this), 0, SweepType.VALIDATE);
        cd = CalldataLib.encodeExternalCall(eoa, ethAmount, false, cd);
        cd = abi.encodeWithSelector(composer.deltaCompose.selector, cd);

        (bool success,) = address(composer).call{value: 0}(cd);

        assertTrue(success, "Call to EOA should succeed");
        assertEq(address(composer).balance, composerInitialBalance - ethAmount, "ETH not transferred to EOA");
    }

    function test_sanity_compose_multiple_transfer_operations(uint16 numOperations) public {
        numOperations = uint8(bound(numOperations, 1, 100));

        address user = address(0x1De17A);
        vm.deal(user, 100 ether);
        vm.label(user, "user");

        MockERC20 mockToken = new MockERC20("Test Token", "TEST", 18);
        address token = address(mockToken);

        uint256 amountPerOperation = 1e18;
        deal(token, user, 1000 ether);

        vm.prank(user);
        IERC20All(token).approve(address(composer), type(uint256).max);

        bytes memory cd = abi.encodePacked(
            CalldataLib.encodeTransferIn(token, address(composer), amountPerOperation), CalldataLib.encodeSweep(token, user, 0, SweepType.VALIDATE)
        );

        bytes memory composedCalls = new bytes(0);
        for (uint8 i = 0; i < numOperations; i++) {
            composedCalls = abi.encodePacked(composedCalls, cd);
        }

        vm.prank(user);
        composer.deltaCompose(composedCalls);
    }
}
