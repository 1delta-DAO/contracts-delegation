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
 * We test Blancer v3 single swaps
 */
contract BalV3LightTest is BaseTest {
    uint256 internal constant forkBlock = 27970029;
    OneDeltaComposerLight oneDV2;
    uint8 internal constant BALANCER_V3_POOL_ID = 0;
    uint8 internal constant UNISWAP_V4_DEX_ID = 55;
    uint8 internal constant BALANCER_V3_ID = 85;

    address internal constant BALANCER_V3_VAULT = 0xbA1333333333a1BA1108E8412f11850A5C319bA9;

    address internal constant USDC_WETH_POOL = 0x1667832E66f158043754aE19461aD54D8b178E1E;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal constant ETH = address(0);

    PoolKey pkUSDCETH;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
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

    function balancerV3Swap(
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
            BALANCER_V3_ID, // dexId !== poolId here
            USDC_WETH_POOL, // pool
            BALANCER_V3_VAULT,
            uint8(0), // caller pays
            uint16(0) // data length
        );
    }

    function test_light_swap_balv3_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.05e18;
        // this is the expected exact amount for the block
        // this is equivalent to a rate of 1995.23716 USDC->WETH
        uint256 approxOut = 99761858;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        // console.logBytes(
        //     abi.encodeWithSelector(
        //         PS.swapB.selector, //
        //         uint256(0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
        //         USDC_WETH_POOL,
        //         tokenIn,
        //         tokenOut,
        //         uint256(4213),
        //         uint256(11111),
        //         hex"6383f2df8b9113f98ec2512238dc535b7d7a2b257e8d2456dd22829f3d7c471a" //
        //     )
        // );

        bytes memory dat = balancerV3Swap(user, tokenIn, tokenOut, amount);

        bytes memory swap = CalldataLib.nextGenDexUnlock(
            BALANCER_V3_VAULT,
            BALANCER_V3_POOL_ID,
            dat //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);

        uint gas = gasleft();

        vm.prank(user);
        oneDV2.deltaCompose(swap);

        gas = gas - gasleft();
        console.log("gas", gas);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
