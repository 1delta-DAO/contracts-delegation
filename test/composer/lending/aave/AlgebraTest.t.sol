// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// solhint-disable no-console
import {console} from "forge-std/console.sol";
import {IERC20All} from "test/shared/interfaces/IERC20All.sol";
import {BaseTest} from "test/shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "test/data/LenderRegistry.sol";
import "test/composer/utils/CalldataLib.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {Masks} from "contracts/1delta/shared/masks/Masks.sol";
import {DeltaErrors} from "contracts/1delta/shared/errors/Errors.sol";

contract AlgebraTest is BaseTest, Masks {
    address private constant CAMELOT_FACTORY = 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B;

    address USDC;
    address WETH;

    IComposerLike oneDV2;

    function setUp() public virtual {
        string memory chainName = Chains.ARBITRUM_ONE;
        _init(chainName, 0, true);

        USDC = chain.getTokenAddress(Tokens.USDC);
        WETH = chain.getTokenAddress(Tokens.WETH);

        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function test_valid_camelot_pool() public {
        address pool = _getPool(USDC, WETH);
        _testSwap(pool, USDC, WETH, user, 1000e6);
    }

    // utils
    function _getPool(address tokenIn, address tokenOut) internal returns (address) {
        (bool success, bytes memory data) = CAMELOT_FACTORY.call(abi.encodeWithSelector(bytes4(0xd9a641e1), tokenIn, tokenOut));
        if (success) {
            return abi.decode(data, (address));
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
        bytes memory swapCalldata = CalldataLib.swapHead(amount, 0, tokenIn);
        swapCalldata = CalldataLib.attachBranch(swapCalldata, 0, 0, new bytes(0));

        return CalldataLib.encodeUniswapV3StyleSwap(swapCalldata, tokenOut, receiver, 3, pool, 3000, DexPayConfig.CALLER_PAYS, new bytes(0));
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
