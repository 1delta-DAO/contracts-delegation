// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {Masks} from "contracts/1delta/shared/masks/Masks.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

contract AlgebraTest is BaseTest, Masks {
    address private constant CAMELOT_FACTORY = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

    address USDC;
    address WETH;
    address WBTC;
    address ARB;

    IComposerLike oneDV2;

    function setUp() public virtual {
        string memory chainName = Chains.ARBITRUM_ONE;
        _init(chainName, 0, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        WBTC = chain.getTokenAddress(Tokens.WBTC);
        ARB = chain.getTokenAddress(Tokens.ARB);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_integ_swap_algebra_validPool() public {
        address pool = _getPool(USDC, WETH);
        _testSwap(pool, USDC, WETH, user, 1000e6);
    }

    function test_integ_swap_algebra_validPoolReverse() public {
        address pool = _getPool(WETH, USDC);
        _testSwap(pool, WETH, USDC, user, 1e18);
    }

    function test_integ_swap_algebra_validPoolDifferentTokens() public {
        address pool = _getPool(WETH, ARB);
        _testSwap(pool, WETH, ARB, user, 0.1e18);
    }

    function test_integ_swap_algebra_zeroAmount() public {
        address pool = _getPool(USDC, WETH);

        vm.startPrank(user);
        vm.expectRevert();
        oneDV2.deltaCompose(_createSwapData(pool, USDC, WETH, user, 0));
        vm.stopPrank();
    }

    function test_integ_swap_algebra_insufficientAllowance() public {
        address pool = _getPool(USDC, WETH);
        uint256 amount = 1000e6;

        deal(USDC, user, amount);
        vm.startPrank(user);

        vm.expectRevert();
        oneDV2.deltaCompose(_createSwapData(pool, USDC, WETH, user, amount));
        vm.stopPrank();
    }

    function test_integ_swap_algebra_insufficientBalance() public {
        address pool = _getPool(USDC, WETH);
        uint256 amount = 1000e6;

        vm.startPrank(user);
        IERC20All(USDC).approve(address(oneDV2), amount);

        vm.expectRevert();
        oneDV2.deltaCompose(_createSwapData(pool, USDC, WETH, user, amount));
        vm.stopPrank();
    }

    function test_integ_swap_algebra_contractPaysConfig() public {
        address pool = _getPool(USDC, WETH);
        uint256 amount = 1000e6;

        deal(USDC, address(oneDV2), amount);

        vm.startPrank(user);

        bytes memory swapData = _createSwapDataWithConfig(pool, USDC, WETH, user, amount, DexPayConfig.CONTRACT_PAYS);

        uint256 balanceBefore = IERC20All(WETH).balanceOf(user);
        oneDV2.deltaCompose(swapData);
        uint256 balanceAfter = IERC20All(WETH).balanceOf(user);

        assertGt(balanceAfter, balanceBefore, "CONTRACT_PAYS swap should work");
        vm.stopPrank();
    }

    // utils
    function _getPool(address tokenIn, address tokenOut) internal returns (address) {
        (bool success, bytes memory data) = CAMELOT_FACTORY.call(abi.encodeWithSelector(bytes4(0xd9a641e1), tokenIn, tokenOut));
        if (success) {
            address pool = abi.decode(data, (address));
            if (pool != address(0)) {
                return pool;
            }
        }
        revert("Failed to get pool");
    }

    function _getFactoryAddress(bytes32 factory) internal pure returns (address) {
        return address(uint160(((uint256(factory) << 8) >> 88)));
    }

    function _createSwapData(
        address pool,
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 amount
    )
        internal
        view
        returns (bytes memory)
    {
        return _createSwapDataWithConfig(pool, tokenIn, tokenOut, receiver, amount, DexPayConfig.CALLER_PAYS);
    }

    function _createSwapDataWithConfig(
        address pool,
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 amount,
        DexPayConfig config
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory swapCalldata = CalldataLib.swapHead(amount, 0, tokenIn);
        swapCalldata = CalldataLib.attachBranch(swapCalldata, 0, 0, new bytes(0));

        return CalldataLib.encodeUniswapV3StyleSwap(swapCalldata, tokenOut, receiver, 3, pool, 3000, config, new bytes(0));
    }

    function _testSwap(address pool, address tokenIn, address tokenOut, address receiver, uint256 amount) internal {
        deal(tokenIn, user, amount);

        vm.startPrank(user);
        IERC20All(tokenIn).approve(address(oneDV2), amount);

        uint256 balanceBefore = IERC20All(tokenOut).balanceOf(user);

        oneDV2.deltaCompose(_createSwapData(pool, tokenIn, tokenOut, receiver, amount));

        uint256 balanceAfter = IERC20All(tokenOut).balanceOf(user);
        assertGt(balanceAfter, balanceBefore, "Swap should increase output token balance");

        vm.stopPrank();
    }
}
