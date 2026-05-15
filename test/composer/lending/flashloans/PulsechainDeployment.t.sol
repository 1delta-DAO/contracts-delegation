// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {FlashLoanIds} from "contracts/1delta/composer/enums/DeltaEnums.sol";
import {IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

/// @notice Probes the actual deployed pulsechain composer contracts referenced
///         in scripts/_shared/addresses.ts and confirms whether each accepts
///         the post-change Phiat + Better Bank flash-loan encodings.
contract PulsechainDeploymentTest is BaseTest {
    /// @dev Updated to the real TransparentUpgradeableProxy on pulsechain.
    /// Pre-upgrade these probes are expected to revert (proxy still points at the old impl);
    /// after `ProxyAdmin(0xbb7eaaaf…).upgradeAndCall(proxy, LOGIC, 0x)` they should pass.
    address internal constant COMPOSER_PROXIES_PULSECHAIN = 0x8E24CfC19c6C00c524353CB8816f5f1c2F33c201;
    address internal constant COMPOSER_LOGICS_PULSECHAIN = 0x4b5458BB47dCBC1a41B31b41e1a8773dE312BE9d;

    address internal constant PHIAT_POOL = 0xC14B5DE7fbdFF428f64AA9E7E240EA342EE9a3A3;
    address internal constant BETTER_BANK_POOL = 0xEC521218747d6ac1b3a9BD72a6F81Cb130309889;
    address internal constant BETTER_BANK_ATROPA_POOL = 0x000dEdABed8122422FfBA497458C4bd6cC4F69f7;
    address internal constant ATROPA = 0xCc78A0acDF847A2C1714D2A925bB4477df5d48a6;

    address internal WPLS;

    function setUp() public virtual {
        _init(Chains.PULSECHAIN, 0, true);
        WPLS = chain.getTokenAddress(Tokens.WPLS);
    }

    function _phiatPayload() internal view returns (bytes memory) {
        uint256 sweepAm = 1.0e18;
        bytes memory dp = CalldataLib.encodeSweep(address(0), user, sweepAm, SweepType.AMOUNT);
        return CalldataLib.encodeFlashLoan(WPLS, 1.0e18, PHIAT_POOL, uint8(FlashLoanIds.AAVE_V2), uint8(16), dp);
    }

    function _betterBankPayload(address pool, uint8 poolId, address asset) internal view returns (bytes memory) {
        uint256 sweepAm = 1.0e18;
        bytes memory dp = CalldataLib.encodeSweep(address(0), user, sweepAm, SweepType.AMOUNT);
        return CalldataLib.encodeFlashLoan(asset, 1.0e18, pool, uint8(FlashLoanIds.AAVE_V3), poolId, dp);
    }

    function _tryCompose(address composer, bytes memory payload, uint256 fee, address asset) internal returns (bool ok) {
        vm.deal(composer, 2.0e18);
        if (fee > 0) deal(asset, composer, fee);
        vm.prank(user);
        (ok,) = composer.call(abi.encodeWithSelector(IComposerLike.deltaCompose.selector, payload));
    }

    function test_deployment_PROXIES_phiat() external {
        bool ok = _tryCompose(COMPOSER_PROXIES_PULSECHAIN, _phiatPayload(), 1.0e18 * 9 / 10000, WPLS);
        console.log("COMPOSER_PROXIES accepts Phiat (new 5-arg):", ok);
    }

    function test_deployment_LOGICS_phiat() external {
        bool ok = _tryCompose(COMPOSER_LOGICS_PULSECHAIN, _phiatPayload(), 1.0e18 * 9 / 10000, WPLS);
        console.log("COMPOSER_LOGICS accepts Phiat (new 5-arg):", ok);
    }

    function test_deployment_PROXIES_betterBank() external {
        bool ok = _tryCompose(
            COMPOSER_PROXIES_PULSECHAIN,
            _betterBankPayload(BETTER_BANK_POOL, 102, WPLS),
            1.0e18 * 5 / 10000,
            WPLS
        );
        console.log("COMPOSER_PROXIES accepts Better Bank:", ok);
    }

    function test_deployment_LOGICS_betterBank() external {
        bool ok = _tryCompose(
            COMPOSER_LOGICS_PULSECHAIN,
            _betterBankPayload(BETTER_BANK_POOL, 102, WPLS),
            1.0e18 * 5 / 10000,
            WPLS
        );
        console.log("COMPOSER_LOGICS accepts Better Bank:", ok);
    }

    function test_deployment_LOGICS_betterBankAtropa() external {
        bool ok = _tryCompose(
            COMPOSER_LOGICS_PULSECHAIN,
            _betterBankPayload(BETTER_BANK_ATROPA_POOL, 103, ATROPA),
            1.0e18 * 5 / 10000,
            ATROPA
        );
        console.log("COMPOSER_LOGICS accepts Better Bank Atropa:", ok);
    }
}
