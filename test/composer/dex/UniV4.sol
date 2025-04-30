// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {PoolKey, SwapParams, PS, BalanceDelta} from "./utils/UniV4Utils.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

/**
 * We test UniV4 single swaps
 */
contract UnoV4LightTest is BaseTest {
    uint256 internal constant forkBlock = 27970029;
    IComposerLike oneDV2;
    uint8 internal constant UNISWAP_V4_POOL_ID = 0;

    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal constant ETH = address(0);

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function unoV4Swap(
        address user, //
        address tokenIn,
        address tokenOut,
        uint256 amount
    )
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1),
            //
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
            uint8(0), // caller pays
            uint16(0) // data length
        );
    }

    function test_light_swap_v4_single() external {
        vm.assume(user != address(0));

        address tokenIn = ETH;
        address tokenOut = USDC;
        uint256 amount = 1.0e18;
        // this is the expected exact amount for the block
        // this is equivalent to a rate of 2016.643281 USDC->WETH
        uint256 approxOut = 2016643281;
        if (tokenIn != ETH) {
            deal(tokenIn, user, amount);
        } else {
            deal(user, amount);
        }

        if (tokenIn != ETH) {
            vm.prank(user);
            IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);
        }

        // console.logBytes(
        //     abi.encodeWithSelector(
        //         PS.swap.selector, //
        //         PoolKey(
        //             WETH,
        //             USDC,
        //             500,
        //             10,
        //             address(0) // no hook
        //         ),
        //         true,
        //         int256(111),
        //         uint160(99),
        //         hex"6383f2df8b9113f98ec2512238dc535b7d7a2b257e8d2456dd22829f3d7c471a" //
        //     )
        // );

        bytes memory dat = unoV4Swap(user, tokenIn, tokenOut, amount);

        bytes memory swap = CalldataLib.encodeNextGenDexUnlock(
            UNI_V4_PM,
            UNISWAP_V4_POOL_ID,
            dat //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        uint256 gas = gasleft();

        if (tokenIn != ETH) {
            vm.prank(user);
            oneDV2.deltaCompose(swap);
        } else {
            vm.prank(user);
            oneDV2.deltaCompose{value: amount}(swap);
        }

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
