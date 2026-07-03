// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {FlashLoanIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

/// @notice Fork tests that prove the on-chain Better Bank pools expose the
///         Aave-V3 `flashLoanSimple(address,address,uint256,bytes,uint16)`
///         selector and call back into the composer via
///         `executeOperation(address,uint256,uint256,address,bytes)`.
contract BetterBankFlashLoanTest is BaseTest {
    IComposerLike oneD;

    uint256 internal constant forkBlock = 0; // latest

    /// @dev poolIds match the AaveV3FlashLoanCallback whitelist on pulsechain.
    uint8 internal constant BETTER_BANK_POOL_ID = 102;
    uint8 internal constant BETTER_BANK_ATROPA_POOL_ID = 103;

    /// @dev Atropa pool has its own asset set, pick one with confirmed liquidity.
    address internal constant ATROPA = 0xCc78A0acDF847A2C1714D2A925bB4477df5d48a6;

    address internal BETTER_BANK_POOL;
    address internal BETTER_BANK_ATROPA_POOL;
    address internal WPLS;

    function setUp() public virtual {
        string memory chainName = Chains.PULSECHAIN;

        _init(chainName, forkBlock, true);

        oneD = ComposerPlugin.getComposer(chainName);
        BETTER_BANK_POOL = chain.getLendingController(Lenders.BETTER_BANK);
        BETTER_BANK_ATROPA_POOL = chain.getLendingController(Lenders.BETTER_BANK_ATROPA);
        WPLS = chain.getTokenAddress(Tokens.WPLS);
    }

    function _runFlashLoan(address asset, address pool, uint8 poolId, uint256 amount) internal {
        // 5 bps Aave V3 premium for both Better Bank pools
        uint256 fee = amount * 5 / 10000;

        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        deal(asset, address(oneD), fee);

        bytes memory dp = CalldataLib.encodeSweep(address(0), user, sweepAm, SweepType.AMOUNT);

        bytes memory d = CalldataLib.encodeFlashLoan(asset, amount, pool, uint8(FlashLoanIds.AAVE_V3), poolId, dp);

        uint256 gas = gasleft();
        vm.prank(user);
        oneD.deltaCompose(d);
        gas = gas - gasleft();
        console.log("gas", gas);
    }

    function test_unit_lending_flashloans_betterBank_basic() external {
        _runFlashLoan(WPLS, BETTER_BANK_POOL, BETTER_BANK_POOL_ID, 1.0e18);
    }

    function test_unit_lending_flashloans_betterBank_atropa_basic() external {
        _runFlashLoan(ATROPA, BETTER_BANK_ATROPA_POOL, BETTER_BANK_ATROPA_POOL_ID, 1.0e18);
    }

    function test_unit_lending_flashloans_betterBank_unauthorizedCallback() external {
        bytes memory params = abi.encodePacked(user, BETTER_BANK_POOL_ID);

        vm.expectRevert();
        oneD.executeOperation(WPLS, 1.0e18, 0, address(oneD), params);
    }
}
