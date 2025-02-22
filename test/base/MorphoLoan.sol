// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";

import {OneDeltaComposerBase} from "../../contracts/1delta/modules/base/Composer.sol";

/// @title IMorphoFlashLoanCallback
/// @notice Interface that users willing to use `flashLoan`'s callback must implement.
interface IMorphoFlashLoanCallback {
    /// @notice Callback called when a flash loan occurs.
    /// @dev The callback is called only if data is not empty.
    /// @param assets The amount of assets that was flash loaned.
    /// @param data Arbitrary data passed to the `flashLoan` function.
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;

    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

/**
 * We test flash swap executions using exact in trade types (given that the first pool supports flash swaps)
 * These are always applied on margin, however, we make sure that we always get
 * The expected amounts. Exact out swaps always execute flash swaps whenever possible.
 */
contract FlashLoanTestMorpho is Test, ComposerUtils {
    OneDeltaComposerBase oneD;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneD = new OneDeltaComposerBase();
    }

    function test_base_flsah_loan_morpho() external {
        address asset = 0x4200000000000000000000000000000000000006;
        address user = address(984327);
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), 30.0e18);
        uint256 amount = 11111;
        bytes memory dp = sweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );

        bytes memory d = encodeFlashLoan(
            asset,
            amount,
            uint8(254), //
            dp
        );
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.onMorphoFlashLoan(0, d);
    }
}
