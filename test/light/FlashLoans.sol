// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {ComposerUtils, Commands} from "../shared/utils/ComposerUtils.sol";
import {MorphoMathLib} from "./utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "./utils/CalldataLib.sol";

contract FlashLoanLightTest is BaseTest {
    using MorphoMathLib for uint256;

    OneDeltaComposerLight oneD;

    uint256 internal constant forkBlock = 26696865;

    address internal MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal AAVE_V3_POOL;
    address internal GRANARY_POOL;
    address private BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    // balancer dex data
    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    address internal WETH;
    address internal USDC;

    function setUp() public virtual {
        _init(Chains.BASE, forkBlock);
        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        GRANARY_POOL = chain.getLendingController(Lenders.GRANARY);
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

    function test_light_flash_loan_balancerV3() external {
        address assetFlash = USDC;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 432.0e6;
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );

        bytes memory sweep = CalldataLib.sweep(
            assetFlash,
            BALANCER_V3_VAULT,
            amount, //
            CalldataLib.SweepType.AMOUNT
        );

        bytes memory unlock = CalldataLib.balancerV3FlashLoan(
            BALANCER_V3_VAULT,
            DexForkMappings.BALANCER_V3,
            assetFlash,
            address(oneD),
            amount,
            abi.encodePacked(dp, sweep) //
        );
        vm.prank(user);
        oneD.deltaCompose(unlock);

        vm.expectRevert(bytes4(keccak256("BadPool()")));
        oneD.balancerUnlockCallback(dp);
    }

    function test_light_flash_loan_uniswapV4() external {
        address assetFlash = USDC;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 432.0e6;
        bytes memory dp = CalldataLib.sweep(
            address(0),
            user,
            sweepAm, //
            CalldataLib.SweepType.AMOUNT
        );

        bytes memory sweep = CalldataLib.sweep(
            assetFlash,
            UNI_V4_PM,
            amount, //
            CalldataLib.SweepType.AMOUNT
        );

        bytes memory unlock = CalldataLib.uniswapV4FlashLoan(
            UNI_V4_PM,
            DexForkMappings.UNISWAP_V4,
            assetFlash,
            address(oneD),
            amount,
            abi.encodePacked(dp, sweep) //
        );
        vm.prank(user);
        oneD.deltaCompose(unlock);

        vm.expectRevert(bytes4(keccak256("BadPool()")));
        oneD.unlockCallback(dp);
    }
}
