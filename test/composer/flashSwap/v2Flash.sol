// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
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

    function v2poolFlashSwap(
        address assetIn,
        address assetOut, //
        uint8 dexId,
        address receiver,
        uint256 amount,
        bytes memory callbackData
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = IF(UNI_V2_FACTORY).getPair(assetIn, assetOut);
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
        console.log("callbackData.length", callbackData.length);
        console.logBytes(callbackData);
        data = abi.encodePacked(
            data,
            assetOut,
            receiver,
            dexId,
            // v2 pool data
            pool,
            uint16(9970), // fee denom
            uint8(DexForkMappings.UNISWAP_V2),
            uint16(callbackData.length), // cll length <- user pays
            callbackData
        );
    }

    /**
     * Flash swap open on aave v3 using Uniswap V2
     */
    function test_integ_flashSwap_aave_flash_swap_v2_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        address pool = AAVE_V3_POOL;
        uint256 amount = 0.1e18;
        uint256 borrowAmount = 200.0e6;
        deal(tokenOut, user, 0.1e18);

        depositToAave(tokenOut, user, amount, pool);

        address vToken = _getDebtToken(tokenIn);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        address uniPool = IF(UNI_V2_FACTORY).getPair(tokenIn, tokenOut);
        // borrow and deposit with override amounts (optimal)
        bytes memory borrow = CalldataLib.encodeAaveBorrow(tokenIn, borrowAmount, uniPool, 2, pool);
        bytes memory action = CalldataLib.encodeAaveDeposit(tokenOut, 0, user, pool);

        action = v2poolFlashSwap(
            tokenIn,
            tokenOut, //
            uint8(DexTypeMappings.UNISWAP_V2_ID),
            address(oneDV2),
            borrowAmount,
            abi.encodePacked(action, borrow)
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
