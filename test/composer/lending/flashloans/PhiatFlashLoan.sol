// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {FlashLoanIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

contract PhiatFlashLoanTest is BaseTest {
    IComposerLike oneD;

    uint256 internal constant forkBlock = 0; // latest

    /// @dev Phiat poolId encoded in the params, validated by the AaveV2 callback.
    uint8 internal constant PHIAT_POOL_ID = 16;

    address internal PHIAT_POOL;
    address internal WPLS;

    function setUp() public virtual {
        string memory chainName = Chains.PULSECHAIN;

        _init(chainName, forkBlock, true);

        oneD = ComposerPlugin.getComposer(chainName);
        PHIAT_POOL = chain.getLendingController(Lenders.PHIAT);
        WPLS = chain.getTokenAddress(Tokens.WPLS);
    }

    function test_unit_lending_flashloans_phiat_basic() external {
        address asset = WPLS;
        uint256 amount = 1.0e18;
        uint256 fee = amount * 9 / 10000; // 0.09% Phiat premium

        // sweep native back to user inside the callback as a no-op compose payload
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);

        // fund the composer with the premium so the pool can pull (amount + fee)
        deal(asset, address(oneD), fee);

        bytes memory dp = CalldataLib.encodeSweep(address(0), user, sweepAm, SweepType.AMOUNT);

        bytes memory d = CalldataLib.encodeFlashLoan(asset, amount, PHIAT_POOL, uint8(FlashLoanIds.AAVE_V2), PHIAT_POOL_ID, dp);

        uint256 gas = gasleft();
        vm.prank(user);
        oneD.deltaCompose(d);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_unit_lending_flashloans_phiat_unauthorizedCallback() external {
        // direct invocation of the callback by a non-pool address must revert
        address[] memory assets = new address[](1);
        assets[0] = WPLS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1.0e18;
        uint256[] memory premiums = new uint256[](1);
        premiums[0] = 0;

        bytes memory params = abi.encodePacked(user, PHIAT_POOL_ID);

        vm.expectRevert();
        oneD.executeOperation(assets, amounts, premiums, address(oneD), params);
    }
}
