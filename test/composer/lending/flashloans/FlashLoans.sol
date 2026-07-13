// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {MorphoMathLib} from "test/composer/lending/utils/MathLib.sol";
import {MarketParams, IMorphoEverything} from "test/composer/lending/utils/Morpho.sol";

import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {DexForkMappings} from "contracts/1delta/composer/quoter/dex/DexForkMappings.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

interface IUniV3FactoryLike {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

contract FlashLoanLightTest is BaseTest {
    using MorphoMathLib for uint256;

    IComposerLike oneD;

    uint256 internal constant forkBlock = 26696865;

    address internal MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address internal AAVE_V3_POOL;
    address internal GRANARY_POOL;
    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    // balancer dex data
    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    address internal WETH;
    address internal USDC;

    function setUp() public virtual {
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);

        oneD = ComposerPlugin.getComposer(chainName);
        AAVE_V3_POOL = chain.getLendingController(Lenders.AAVE_V3);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        GRANARY_POOL = chain.getLendingController(Lenders.GRANARY);
    }

    uint256 internal constant UPPER_BIT = 1 << 255;

    function test_unit_lending_flashloans_morpho_basic() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 11111;
        bytes memory dp = CalldataLib.encodeSweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
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

    function test_unit_lending_flashloans_aaveV3_basic() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 1.0e18;
        deal(asset, address(oneD), 0.0005e18); // fee
        bytes memory dp = CalldataLib.encodeSweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            AAVE_V3_POOL,
            uint8(2), // aave v3 type
            uint8(0), // the aave V3
            dp
        );
        uint256 gas = gasleft();
        vm.prank(user);
        oneD.deltaCompose(d);
        gas = gas - gasleft();
        console.log("gas", gas);

        vm.expectRevert();
        oneD.executeOperation(asset, 0, 9, user, d);
    }

    function test_unit_lending_flashloans_aaveV2_basic() external {
        address asset = WETH;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 1.0e18;
        deal(asset, address(oneD), 0.0009e18); // fee
        bytes memory dp = CalldataLib.encodeSweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );
        bytes memory d = CalldataLib.encodeFlashLoan(
            asset,
            amount,
            GRANARY_POOL,
            uint8(3), // aave v2
            uint8(7), //is Granary in the auto-gen setup
            dp
        );
        vm.prank(user);
        oneD.deltaCompose(d);

        vm.expectRevert();
        oneD.executeOperation(asset, 0, 9, user, d);
    }

    function test_unit_lending_flashloans_balancerV3_basic() external {
        address assetFlash = USDC;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 432.0e6;
        bytes memory dp = CalldataLib.encodeSweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );

        bytes memory sweep = CalldataLib.encodeSweep(
            assetFlash,
            BALANCER_V3_VAULT,
            amount, //
            SweepType.AMOUNT
        );

        bytes memory unlock = CalldataLib.encodeBalancerV3FlashLoan(
            BALANCER_V3_VAULT,
            DexForkMappings.BALANCER_V3,
            assetFlash,
            address(oneD),
            amount,
            abi.encodePacked(dp, sweep) //
        );

        uint256 gas = gasleft();

        vm.prank(user);
        oneD.deltaCompose(unlock);

        gas = gas - gasleft();
        console.log("gas", gas);

        /**
         * this cannot happen anymore as we use single poolId without fallbacks
         */
        // vm.expectRevert(bytes4(keccak256("BadPool()")));
        // oneD.balancerUnlockCallback(abi.encodePacked(address(99), uint8(1), dp));

        vm.expectRevert(bytes4(keccak256("InvalidCaller()")));
        oneD.balancerUnlockCallback(abi.encodePacked(address(99), uint8(0), dp));
    }

    function test_unit_lending_flashloans_uniswapV3_basic() external {
        // Uniswap V3 factory on base; forkId 0 = UNISWAP_V3 (Classic family)
        address factory = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
        (address token0, address token1) = WETH < USDC ? (WETH, USDC) : (USDC, WETH);
        address pool = IUniV3FactoryLike(factory).getPool(token0, token1, 500);
        require(pool != address(0), "no univ3 pool");

        address assetFlash = USDC;
        uint256 amount = 1_000e6; // borrow 1000 USDC
        uint256 fee = (amount * 500 + 1e6 - 1) / 1e6; // 0.05% rounded up
        deal(assetFlash, address(oneD), fee + 10); // pre-fund the fee (principal comes from the flash)

        // compose op executed inside the callback: repay principal + fee back to the pool
        bytes memory repay = CalldataLib.encodeSweep(assetFlash, pool, amount + fee, SweepType.AMOUNT);

        // borrow USDC -> whichever side USDC is
        uint128 amount0 = token0 == USDC ? uint128(amount) : 0;
        uint128 amount1 = token1 == USDC ? uint128(amount) : 0;

        bytes memory d = CalldataLib.encodeUniswapV3FlashLoan(
            0, // forkId UNISWAP_V3
            pool,
            token0,
            token1,
            500, // fee tier
            amount0,
            amount1,
            repay
        );

        uint256 gas = gasleft();
        vm.prank(user);
        oneD.deltaCompose(d);
        gas = gas - gasleft();
        console.log("univ3 flash gas", gas);

        // a caller that is not the deterministic pool must be rejected
        vm.expectRevert(bytes4(keccak256("BadPool()")));
        oneD.uniswapV3FlashCallback(0, 0, repay);
    }

    function test_unit_lending_flashloans_uniswapV4_basic() external {
        address assetFlash = USDC;
        uint256 sweepAm = 30.0e18;
        vm.deal(address(oneD), sweepAm);
        uint256 amount = 432.0e6;
        bytes memory dp = CalldataLib.encodeSweep(
            address(0),
            user,
            sweepAm, //
            SweepType.AMOUNT
        );

        bytes memory sweep = CalldataLib.encodeSweep(
            assetFlash,
            UNI_V4_PM,
            amount, //
            SweepType.AMOUNT
        );

        bytes memory unlock = CalldataLib.encodeUniswapV4FlashLoan(
            UNI_V4_PM,
            DexForkMappings.UNISWAP_V4,
            assetFlash,
            address(oneD),
            amount,
            abi.encodePacked(dp, sweep) //
        );

        uint256 gas = gasleft();

        vm.prank(user);
        oneD.deltaCompose(unlock);

        gas = gas - gasleft();
        console.log("gas", gas);

        /**
         * this cannot happen anymore as we use single poolId without fallbacks
         */
        // vm.expectRevert(bytes4(keccak256("BadPool()")));
        // oneD.unlockCallback(abi.encodeWithSelector(oneD.balancerUnlockCallback.selector, abi.encodePacked(address(99), uint8(1), dp)));

        vm.expectRevert(bytes4(keccak256("InvalidCaller()")));
        oneD.unlockCallback(
            abi.encodeWithSelector(oneD.balancerUnlockCallback.selector, abi.encodePacked(address(99), uint8(0), dp))
        );
    }
}
