// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IFactoryAndPair {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

/**
 * Mimics a uniswap v2 type pool
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

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        /// theft txn that would pull from callerAddress
        bytes memory stealFunds = CalldataLib.encodeTransferIn(TOKEN, attacker, IERC20All(TOKEN).balanceOf(VICTIM));
        // inject a valid callback selecor with victim address
        IUniswapV2Callee(to).uniswapV2Call(
            msg.sender, amount0Out, amount1Out, abi.encodePacked(VICTIM, TOKEN, TOKEN_OUT, uint8(0), uint16(stealFunds.length), stealFunds)
        );
        // if we reach this, the composer got exploited
        revert("EXPLOITED");
    }

    // this one is needed to comply with the quoting logic
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = 1000;
        _reserve1 = 1000;
        _blockTimestampLast = 99;
    }
}

contract FlashSwapTestV2Security is BaseTest {
    address internal constant UNI_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    uint256 internal attackerPk = 0xbad0;
    address internal attacker = vm.addr(attackerPk);

    IComposerLike oneDV2;

    address internal USDC;
    address internal WETH;

    uint256 internal constant forkBlock = 23969720;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ETHEREUM_MAINNET;

        _init(chainName, forkBlock, true);
        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function v2poolFlashSwapViaPool(
        address assetIn,
        address assetOut, //
        address pool,
        address receiver,
        uint256 amount,
        uint256 forkId
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
            uint8(DexTypeMappings.UNISWAP_V2_ID), // <- fix dexId
            // v2 pool data
            pool,
            uint16(9970), // fee denom
            uint8(forkId), // <- forkId
            uint16(4), // <- ignore calldata
            uint32(0) // empty
        );
    }

    /**
     * Exploit attempt: try to call the CB directly to the composer
     */
    function test_security_flashSwap_flash_swap_v2_caller() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        address pair = IFactoryAndPair(UNI_V2_FACTORY).getPair(tokenIn, tokenOut);
        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("BadPool()");
        IUniswapV2Callee(address(oneDV2)).uniswapV2Call(
            address(oneDV2), 10, 10, abi.encodePacked(user, tokenIn, tokenOut, uint8(0), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Exploit attempt: try to trigger the CB on the composer by calling swap with composer as target
     */
    function test_security_flashSwap_flash_swap_v2_remote_call_to_composer() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        address pair = IFactoryAndPair(UNI_V2_FACTORY).getPair(tokenIn, tokenOut);
        bytes memory stealFunds = CalldataLib.encodeTransferIn(tokenIn, attacker, IERC20All(tokenIn).balanceOf(user));

        vm.prank(attacker);
        vm.expectRevert("InvalidCaller()");
        IFactoryAndPair(pair).swap(
            10000, 0, address(oneDV2), abi.encodePacked(user, tokenIn, tokenOut, uint8(0), uint16(stealFunds.length), stealFunds)
        );
    }

    /**
     * Exploit attempt: create fake pool and try re-enter with theft
     */
    function test_security_flashSwap_flash_swap_v2_scam_pool() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint256 amount = 0.1e18;
        deal(tokenIn, user, 0.1e18);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        vm.prank(attacker);
        address pair = address(new FakePool(user, tokenIn, tokenOut));

        bytes memory badCalldata = v2poolFlashSwapViaPool(tokenIn, tokenOut, pair, address(oneDV2), 100000, DexForkMappings.UNISWAP_V2);

        vm.prank(attacker);
        vm.expectRevert("BadPool()");
        oneDV2.deltaCompose(badCalldata);
    }
}
