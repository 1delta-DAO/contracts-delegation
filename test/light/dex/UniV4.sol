// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {OneDeltaComposerLight} from "../../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {PoolKey, SwapParams, PS, BalanceDelta} from "./utils/UniV4Utils.sol";

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract UnoV4LightTest is BaseTest {
    uint256 internal constant forkBlock = 27970029;
    OneDeltaComposerLight oneDV2;
    uint8 internal constant UNISWAP_V4_POOL_ID = 0;
    uint8 internal constant UNISWAP_V4_DEX_ID = 55;

    address internal constant UNI_V4_PM = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant ETH = address(0);

    PoolKey pkUSDCETH;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerLight(address(0));
        pkUSDCETH = PoolKey(
            address(0),
            USDC,
            500,
            10, //
            address(0)
        );
    }

    function unoV4Unlock(bytes memory d) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            uint8(ComposerCommands.UNI_V4),
            uint8(UniswapV4ActionIds.UNLOCK),
            UNI_V4_PM, // manager address
            UNISWAP_V4_POOL_ID, // validation Id
            uint16(d.length),
            d
        ); // swaps max index for inner path
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
            UNISWAP_V4_DEX_ID, // DODO
            address(0), // hook
            UNI_V4_PM,
            uint24(500),
            uint24(10),
            uint8(0), // caller pays
            uint16(0) // data length
        );
    }

    function test_light_swap_v4_single() external {
        vm.assume(user != address(0));

        address tokenIn = ETH;
        address tokenOut = USDC;
        uint256 amount = 1.0e18;
        uint256 approxOut = 2016643281; // this is the expected exact amount for the block
        if (tokenIn != ETH) {
            deal(tokenIn, user, amount);
        } else {
            deal(user, amount);
        }

        if (tokenIn != ETH) {
            vm.prank(user);
            IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);
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

        bytes memory swap = unoV4Unlock(
            dat //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        if (tokenIn != ETH) {
            vm.prank(user);
            oneDV2.deltaCompose(swap);
        } else {
            vm.prank(user);
            oneDV2.deltaCompose{value: amount}(swap);
        }
        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    function encodePK(PoolKey memory pk) public view returns (bytes memory data) {
        // pk
    }
}
