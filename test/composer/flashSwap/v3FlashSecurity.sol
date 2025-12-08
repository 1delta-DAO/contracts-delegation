// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IFactoryAndPair {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/**
 * Mimics a Uniswap V3 type pool
 */
contract FakePool {
    address internal immutable VICTIM;
    address internal immutable TOKEN;
    address internal immutable TOKEN_OUT;
    address internal immutable attacker;

    constructor(address victim, address tokenToSteal, address tokenOut) {
        VICTIM = victim;
        TOKEN = tokenToSteal;
        TOKEN_OUT = tokenOut;
        attacker = msg.sender;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    )
        external
        returns (int256 amount0, int256 amount1)
    {
        /// theft txn that would pull from callerAddress
        bytes memory stealFunds = CalldataLib.encodeTransferIn(TOKEN, attacker, IERC20All(TOKEN).balanceOf(VICTIM));

        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
            int256(99), int256(99), abi.encodePacked(VICTIM, TOKEN, TOKEN_OUT, uint8(0), uint16(500), uint16(stealFunds.length), stealFunds)
        );
    }
}

contract FlashSwapTestV3Security is BaseTest {
    address internal constant UNI_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
    IComposerLike oneDV2;

    uint256 internal attackerPk = 0xbad0;
    address internal attacker = vm.addr(attackerPk);

    address internal USDC;
    address internal WETH;

    string internal lender;

    uint256 internal constant forkBlock = 23969720;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);
        lender = Lenders.AAVE_V3;
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function v3poolFlashSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        address pool,
        address receiver,
        uint256 amount
    )
        internal
        view
        returns (bytes memory data)
    {
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
            uint8(DexForkMappings.UNISWAP_V3), // <- the actual uni v3
            fee,
            uint16(4), // cll length <- user pays
            uint48(99) // 4 bytes to comply with composer calldata
        );
    }

    /**
     * Exploit attempt: call callback and try re-enter with theft
     */
    function test_security_flashSwap_flash_swap_v3_caller() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        address pair = IFactoryAndPair(UNI_FACTORY).getPool(tokenIn, tokenOut, 500);
        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("BadPool()");
        IUniswapV3SwapCallback(address(oneDV2)).uniswapV3SwapCallback(
            int256(990), int256(990), abi.encodePacked(user, tokenIn, tokenOut, uint8(0), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Exploit attempt: create fake pool and try re-enter with theft
     */
    function test_security_flashSwap_flash_swap_v3_scam_pool() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        vm.prank(attacker);
        address pool = address(new FakePool(user, tokenIn, tokenOut));

        // bytes memory badCalldata = v2poolFlashSwapViaPool(tokenIn, tokenOut, pair, address(oneDV2), 100000, DexForkMappings.UNISWAP_V2);

        bytes memory badCalldata = v3poolFlashSwap(
            tokenIn,
            tokenOut, //
            500,
            pool,
            address(oneDV2),
            amount
        );

        vm.prank(attacker);
        vm.expectRevert("BadPool()");
        oneDV2.deltaCompose(badCalldata);
    }
}
