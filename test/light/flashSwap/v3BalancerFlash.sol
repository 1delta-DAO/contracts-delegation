// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "../utils/Morpho.sol";

import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract BalancerFlashSwapTest is BaseTest {
    uint8 internal constant UNI_V3_DEX_ID = 0;

    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal AAVE_V3_POOL;
    address internal constant ETH = address(0);

    string internal lender;

    uint256 internal constant forkBlock = 27970029;
    uint8 internal constant BALANCER_V3_POOL_ID = 0;

    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;
    address internal constant USDC_WETH_POOL = 0x1667832E66f158043754aE19461aD54D8b178E1E;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        lender = Lenders.AAVE_V3;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        AAVE_V3_POOL = chain.getLendingController(lender);

        oneDV2 = new OneDeltaComposerLight(address(0));
    }

    function balV3Swap(
        address user, //
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1), //
            tokenIn,
            uint8(0), // swaps max index
            uint8(0) // splits
        ); // swaps max index for inner path
        data = abi.encodePacked(
            data,
            tokenOut,
            user,
            uint8(DexTypeMappings.BALANCER_V3_ID), // dexId !== poolId here
            USDC_WETH_POOL, // pool
            BALANCER_V3_VAULT,
            uint8(3), // caller pays
            uint16(0) // data length
        );
    }

    /**
     * Flash swap open on aave v3 using Uniswap V3
     */
    function test_light_aave_flash_swap_balancer_v3_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = USDC;
        address pool = AAVE_V3_POOL;
        uint256 depoistAmount = 50.0e6;
        uint256 borrowAmount = 0.05e18;
        deal(tokenOut, user, depoistAmount);

        depositToAave(tokenOut, user, depoistAmount, pool);

        address vToken = _getDebtToken(tokenIn);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        bytes memory swapAction = balV3Swap(address(oneDV2), tokenIn, tokenOut, borrowAmount);
        {
            // borrow and deposit with override amounts (optimal)
            bytes memory borrow = CalldataLib.encodeAaveBorrow(tokenIn, false, borrowAmount, address(BALANCER_V3_VAULT), 2, pool);
            bytes memory deposit = CalldataLib.encodeAaveDeposit(tokenOut, false, 0, user, pool);

            bytes memory settlementActions = CalldataLib.nextGenDexSettleBalancer(
                BALANCER_V3_VAULT, //
                tokenIn,
                borrowAmount
            );

            swapAction = CalldataLib.nextGenDexUnlock(
                BALANCER_V3_VAULT,
                BALANCER_V3_POOL_ID,
                abi.encodePacked(
                    swapAction, // the swap
                    deposit,
                    borrow,
                    settlementActions
                ) //
            );
        }
        // Check balances before action
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, tokenIn, lender);
        uint256 collateralBefore = chain.getCollateralBalance(user, tokenOut, lender);

        uint gas = gasleft();

        vm.prank(user);
        oneDV2.deltaCompose(swapAction);

        gas = gas - gasleft();
        console.log("gas", gas);

        // Check balances after action
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, tokenIn, lender);
        uint256 collateralAfter = chain.getCollateralBalance(user, tokenOut, lender);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, borrowAmount, 0);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(collateralAfter - collateralBefore, 99761858, 0);
    }

    function depositToAave(address token, address userAddress, uint256 amount, address pool) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.transferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, false, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function _getDebtToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).debt;
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
