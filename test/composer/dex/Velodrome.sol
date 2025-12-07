// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
    function getPool(address tokenA, address tokenB, int24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function getPair(address tokenA, address tokenB, bool isStable) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4646Deposit, encodeErc4646Withdraw
 */
contract Velodrome123Test is BaseTest {
    address internal constant VELODROME_CL_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
    address internal constant VELODROME_V2_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    uint256 internal constant forkBlock = 134997905;
    IComposerLike oneDV2;

    string internal lender;
    uint256 internal constant VELODROME_ID = 19;

    address internal USDC;
    address internal WETH;
    address internal OP;
    address internal AAVE_V3_POOL;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.OP_MAINNET;
        lender = Lenders.AAVE_V3;

        _init(chainName, forkBlock, true);
        OP = chain.getTokenAddress(Tokens.OP);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        AAVE_V3_POOL = chain.getLendingController(lender);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    // banale uniswap direct swap
    // 100% USDC ---uni----> WETH

    function v3poolSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        address receiver,
        uint256 amount
    )
        internal
        view
        returns (bytes memory data)
    {
        console.log("assetIn, assetOut", assetIn, assetOut);
        console.logBytes32(
            keccak256(hex"3d602d80600a3d3981f3363d3d373d3d3d363d7395885Af5492195F0754bE71AD1545Fe81364E5315af43d82803e903d91602b57fd5bf3")
        );
        //     console.logBytes32(keccak256(hex"363d3d373d3d3d363d73${95885Af5492195F0754bE71AD1545Fe81364E531}5af43d82803e903d91602b57fd5bf3"));
        address pool = IF(VELODROME_CL_FACTORY).getPool(assetIn, assetOut, int24(uint24(fee)));
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
            uint8(DexTypeMappings.UNISWAP_V3_ID),
            // v3 pool data
            pool,
            uint8(VELODROME_ID), // <- the actual uni v3
            fee,
            uint16(0) // cll length <- user pays
        );
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
        address pool = IF(VELODROME_V2_FACTORY).getPair(assetIn, assetOut, false);
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
            uint8(138),
            uint16(callbackData.length), // cll length <- user pays
            callbackData
        );
    }

    function test_integ_swap_velodrome3_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 100;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = v3poolSwap(
            tokenIn,
            tokenOut,
            fee,
            user,
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }

    /**
     * Flash swap open on aave v3 using Velodrome V2
     */
    function test_integ_swap_velodrome_aaveFlashSwapVelo2Single() external {
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

        address uniPool = IF(VELODROME_V2_FACTORY).getPair(tokenIn, tokenOut, false);
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
