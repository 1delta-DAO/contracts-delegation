// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {MarketParams, IMorphoEverything} from "test/light/lending/utils/Morpho.sol";

import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "light/Composer.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/light/utils/CalldataLib.sol";

contract FlashSwapTest is BaseTest {
    using CalldataLib for bytes;

    uint8 internal constant UNI_V3_DEX_ID = 0;

    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal AAVE_V3_POOL;
    address internal constant ETH = address(0);

    string internal lender;

    uint256 internal constant forkBlock = 27970029;
    uint8 internal constant UNISWAP_V4_POOL_ID = 0;

    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        lender = Lenders.AAVE_V3;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        AAVE_V3_POOL = chain.getLendingController(lender);

        oneDV2 = new OneDeltaComposerLight();
    }

    function unoV4Swap(
        address user, //
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal pure returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            tokenIn,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        // append swap
        data = data.uniswapV4StyleSwap(
            tokenOut,
            user,
            UNI_V4_PM,
            CalldataLib.UniV4SwapParams(
                500, //
                10,
                address(0),
                hex""
            ),
            CalldataLib.DexPayConfig.PRE_FUND
        );
    }

    /**
     * Flash swap open on aave v3 using Uniswap V3
     */
    function test_light_aave_flash_swap_v4_single() external {
        vm.assume(user != address(0));

        address tokenIn = ETH;
        address tokenOut = USDC;
        address pool = AAVE_V3_POOL;
        uint256 depoistAmount = 2000.0e6;
        uint256 borrowAmount = 1.0e18;
        deal(tokenOut, user, depoistAmount);

        depositToAave(tokenOut, user, depoistAmount, pool);

        address vToken = _getDebtToken(WETH);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        bytes memory swapAction = unoV4Swap(address(oneDV2), tokenIn, tokenOut, borrowAmount);
        {
            // borrow and deposit with override amounts (optimal)
            bytes memory borrow = CalldataLib.encodeAaveBorrow(WETH, false, borrowAmount, address(oneDV2), 2, pool);
            bytes memory deposit = CalldataLib.encodeAaveDeposit(tokenOut, false, 0, user, pool);

            bytes memory settlementActions = CalldataLib.nextGenDexSettle(
                UNI_V4_PM, //
                borrowAmount
            );
            settlementActions = abi.encodePacked(
                CalldataLib.unwrap(address(oneDV2), borrowAmount, CalldataLib.SweepType.AMOUNT), settlementActions
            );

            deposit = abi.encodePacked(
                swapAction, // the swap
                deposit,
                borrow,
                settlementActions
            );

            swapAction = CalldataLib.nextGenDexUnlock(
                UNI_V4_PM, //
                UNISWAP_V4_POOL_ID,
                deposit
            );
        }

        // Check balances before action
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, WETH, lender);
        uint256 collateralBefore = chain.getCollateralBalance(user, tokenOut, lender);

        uint256 gas = gasleft();

        vm.prank(user);
        oneDV2.deltaCompose(swapAction);

        gas = gas - gasleft();
        console.log("gas", gas);

        // Check balances after action
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, WETH, lender);
        uint256 collateralAfter = chain.getCollateralBalance(user, tokenOut, lender);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, borrowAmount, 0);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(collateralAfter - collateralBefore, 2016643282, 0);
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
