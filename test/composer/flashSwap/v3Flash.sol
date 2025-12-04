// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract FlashSwapTest is BaseTest {
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;
    address internal AAVE_V3_POOL;

    string internal lender;

    uint256 internal constant forkBlock = 26696865;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        lender = Lenders.AAVE_V3;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        AAVE_V3_POOL = chain.getLendingController(lender);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function v3poolFlashSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        uint8 dexId,
        address receiver,
        uint256 amount,
        bytes memory callbackData
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        console.log("pool", pool);
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1),
            //
            assetIn,
            uint8(0), // swaps max index
            uint8(0) // splits
            // single split data (no data here)
            // uint8(0), // swaps max index for inner path
        );
        data = abi.encodePacked(
            data,
            assetOut,
            receiver,
            dexId,
            // v3 pool data
            pool,
            uint8(DexForkMappings.UNISWAP_V3), // <- the actual uni v3
            fee,
            uint16(callbackData.length), // cll length <- user pays
            callbackData
        );
    }

    /**
     * Flash swap open on aave v3 using Uniswap V3
     */
    function test_integ_flashSwap_aave_flash_swap_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        address pool = AAVE_V3_POOL;
        uint256 amount = 1.0e18;
        uint256 borrowAmount = 2000.0e6;
        deal(tokenOut, user, 1.0e18);

        depositToAave(tokenOut, user, amount, pool);

        address vToken = _getDebtToken(tokenIn);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        uint16 fee = 500;
        address uniPool = IF(UNI_FACTORY).getPool(tokenIn, tokenOut, fee);
        // borrow and deposit with override amounts (optimal)
        bytes memory borrow = CalldataLib.encodeAaveBorrow(tokenIn, borrowAmount, uniPool, 2, pool);
        bytes memory action = CalldataLib.encodeAaveDeposit(tokenOut, 0, user, pool);

        action = v3poolFlashSwap(
            tokenIn,
            tokenOut, //
            fee,
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            address(oneDV2),
            borrowAmount,
            abi.encodePacked(action, borrow)
        );

        // Check balances before action
        uint256 borrowBalanceBefore = chain.getDebtBalance(user, tokenIn, lender);
        uint256 collateralBefore = chain.getCollateralBalance(user, tokenOut, lender);
        // print gas cost
        {
            uint256 gas = gasleft();

            vm.prank(user);
            oneDV2.deltaCompose(action);

            gas = gas - gasleft();
            console.log("gas", gas);
        }
        // Check balances after action
        uint256 borrowBalanceAfter = chain.getDebtBalance(user, tokenIn, lender);
        uint256 collateralAfter = chain.getCollateralBalance(user, tokenOut, lender);

        // Assert debt increased by borrowed amount
        assertApproxEqAbs(borrowBalanceAfter - borrowBalanceBefore, borrowAmount, 1);
        // Assert underlying increased by borrowed amount
        assertApproxEqAbs(
            collateralAfter - collateralBefore,
            751372963117975909, // assume receivpt of 0.75WETH
            0
        );
    }

    /**
     * Flash swap open on aave v3 using Uniswap V3, but with splits
     * We nest the flash swaps to avoid >1 borrow action
     * This is as optimal as it gets gas-wise, even for ethereum mainnet
     * Approach:
     *
     * flash pool0 {
     *      flash pool1 {
     *          deposit received funds
     *          borrow total amount to pay both pools to self <- we know all amounts as it is exact input
     *          sweep funds to pool0
     *          sweep funds to pool1
     *   }
     * }
     */
    function test_integ_flashSwap_aave_flash_swap_split() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        address pool = AAVE_V3_POOL;
        uint256 amount = 1.0e18;
        uint256 borrowAmount = 2000.0e6;
        deal(tokenOut, user, 1.0e18);

        depositToAave(tokenOut, user, amount, pool);

        address vToken = _getDebtToken(tokenIn);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        // borrow and deposit with override amounts (optimal)
        bytes memory borrow = CalldataLib.encodeAaveBorrow(
            tokenIn,
            borrowAmount, // borrow total exact input amount
            address(oneDV2), // borrow to self
            2,
            pool
        );
        // depost all received
        bytes memory action = CalldataLib.encodeAaveDeposit(
            tokenOut,
            0, // deposit balanceOf(this)
            user,
            pool
        );

        address uniPool = IF(UNI_FACTORY).getPool(tokenIn, tokenOut, 500);
        bytes memory sweep = CalldataLib.encodeSweep(
            tokenIn,
            uniPool,
            borrowAmount / 2, // split payment for first pool
            SweepType.AMOUNT //
        );

        uniPool = IF(UNI_FACTORY).getPool(tokenIn, tokenOut, 3000);
        sweep = abi.encodePacked(
            sweep,
            CalldataLib.encodeSweep(
                tokenIn,
                uniPool, // pay second pool
                borrowAmount / 2, // split payment for second pool
                SweepType.AMOUNT //
            )
        );

        action = v3poolFlashSwap(
            tokenIn,
            tokenOut, //
            500,
            // first pool
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            address(oneDV2),
            borrowAmount / 2,
            abi.encodePacked(
                // | <-- here we could place any swap from output token to any
                action, // deposit
                borrow,
                sweep // pay the pools
            )
        );

        action = v3poolFlashSwap(
            tokenIn,
            tokenOut, //
            3000,
            // second pool
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            address(oneDV2),
            borrowAmount / 2,
            action // nest the prior swap
        );

        vm.prank(user);
        oneDV2.deltaCompose(action);
    }

    function depositToAave(address token, address userAddress, uint256 amount, address pool) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveDeposit(token, amount, userAddress, pool);

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
