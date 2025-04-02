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

contract FlashSwapTest is BaseTest {
    uint8 internal constant UNI_V3_DEX_ID = 0;

    OneDeltaComposerLight oneDV2;

    address internal USDC;
    address internal WETH;
    address internal AAVE_V3_POOL;
    address internal constant ETH = address(0);

    string internal lender;

    uint256 internal constant forkBlock = 27970029;
    uint8 internal constant UNISWAP_V4_POOL_ID = 0;
    uint8 internal constant UNISWAP_V4_DEX_ID = 55;

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
            uint8(DexTypeMappings.UNISWAP_V4_ID), // dexId !== poolId here
            address(0), // hook
            UNI_V4_PM,
            uint24(500), // fee
            uint24(10), // tick spacing
            uint8(3), // nobody pays - settle later
            uint16(0) // data length
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
            settlementActions = abi.encodePacked(CalldataLib.unwrap(address(oneDV2), borrowAmount, CalldataLib.SweepType.AMOUNT), settlementActions);

            swapAction = CalldataLib.nextGenDexUnlock(
                UNI_V4_PM,
                UNISWAP_V4_POOL_ID,
                abi.encodePacked(
                    swapAction, // the swap
                    deposit,
                    borrow,
                    settlementActions
                ) //
            );
        }

        // Check balances before action
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, WETH, lender);
        uint256 collateralBefore = chain.getCollateralBalance(user, tokenOut, lender);

        uint gas = gasleft();

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
