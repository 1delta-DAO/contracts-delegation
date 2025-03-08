// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";
import {CalldataLib} from "./utils/CalldataLib.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";

/**
 * We test all CalldataLib.morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract FlashLoanLightTest is Test, ComposerUtils {
    using MorphoMathLib for uint256;

    OneDeltaComposerLight oneD;

    address internal constant user = address(984327);

    address internal constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerLight();
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    function test_light_flash_loan_morpho() external {
        address asset = 0x4200000000000000000000000000000000000006;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 11111;
        bytes memory dp = sweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeMorphoFlashLoan(
            asset,
            amount,
            MORPHO,
            uint8(0), //
            dp
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.onMorphoFlashLoan(0, d);
    }

}
