// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {ComposerLightBaseTest} from "./ComposerLightBaseTest.sol";
import {ChainIds, TokenNames} from "./chain/Lib.sol";
import "./utils/CalldataLib.sol";

contract FlashLoanLightTest is ComposerLightBaseTest {
    using MorphoMathLib for uint256;

    OneDeltaComposerLight oneD;

    address internal MORPHO;
    address internal AAVE_V3_POOL;
    address internal GRANARY_POOL;
    address private BALANCER_V2_VAULT;

    address internal WETH;

    function setUp() public virtual {
        _init(ChainIds.BASE);
        MORPHO = chain.getTokenAddress(TokenNames.MORPHO);
        AAVE_V3_POOL = chain.getTokenAddress(TokenNames.AaveV3_Pool);
        GRANARY_POOL = chain.getTokenAddress(TokenNames.GRANARY_POOL);
        BALANCER_V2_VAULT = chain.getTokenAddress(TokenNames.BALANCER_V2_VAULT);
        WETH = chain.getTokenAddress(TokenNames.WETH);

        oneD = new OneDeltaComposerLight();
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    function test_light_flash_loan_morpho() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 11111;
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            MORPHO,
            uint8(0), // morpho B type
            uint8(0), // THE morpho B
            dp
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.onMorphoFlashLoan(0, d);
    }

    function test_light_flash_loan_aaveV3() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 1.0e18;
        deal(asset, address(oneD), 0.0005e18); // fee
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            AAVE_V3_POOL,
            uint8(2), // aave v3 type
            uint8(0), // the aave V3
            dp
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.executeOperation(asset, 0, 9, user, d);
    }

    function test_light_flash_loan_aaveV2() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 1.0e18;
        deal(asset, address(oneD), 0.0009e18); // fee
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            GRANARY_POOL,
            uint8(3), // aave v2 type
            uint8(0), //
            dp
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.executeOperation(asset, 0, 9, user, d);
    }

    function test_light_flash_loan_balancerV2() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 1.0e18;
        deal(asset, address(oneD), 0.0009e18); // fee
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );

        bytes memory t = CalldataLib.sweep(
            asset,
            BALANCER_V2_VAULT,
            amount, //
            CalldataLib.SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            BALANCER_V2_VAULT,
            uint8(1), // balancer v2 type
            uint8(0), //
            abi.encodePacked(dp, t)
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.executeOperation(asset, 0, 9, user, d);
    }
}
