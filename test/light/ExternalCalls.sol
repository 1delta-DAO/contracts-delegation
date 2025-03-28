// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {CallForwarder} from "../../contracts/1delta/modules/light/generic/CallForwarder.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "../../contracts/1delta/test/TrivialMockRouter.sol";
import "./utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract ExternalCallsTest is BaseTest {
    CallForwarder cf;

    OneDeltaComposerLight oneDV2;
    TrivialMockRouter router;

    uint256 internal constant forkBlock = 26696865;
    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant KEYCAT = 0x9a26F5433671751C3276a065f57e5a02D2817973;

    function setUp() public virtual {
        // initialize the chain
        _init(Chains.BASE, forkBlock);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        cf = new CallForwarder();
        oneDV2 = new OneDeltaComposerLight(address(cf));
    }


    function test_light_ext_call() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
    
        uint256 amount = 100.0e6;
        deal(tokenIn, user, amount);

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        // bytes memory swap = v3poolSwap(
        //     tokenIn,
        //     tokenOut,
        //     fee,
        //     uint8(0),
        //     user,
        //     amount //
        // );

        // vm.prank(user);
        // oneDV2.deltaCompose(swap);
    }

}
