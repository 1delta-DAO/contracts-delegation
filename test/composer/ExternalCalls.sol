// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CallForwarder} from "../../contracts/1delta/composer/generic/CallForwarder.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../data/LenderRegistry.sol";
import "../mocks/TrivialMockRouter.sol";
import {SweepType} from "contracts/1delta/composer/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";
import {CalldataLib} from "contracts/utils/CalldataLib.sol";

// solhint-disable max-line-length

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4626Deposit, encodeErc4646Withdraw
 */
contract ExternalCallsTest is BaseTest {
    CallForwarder cf;

    IComposerLike oneDV2;
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
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, false);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        cf = new CallForwarder();
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function extCall(address asset, uint256 amount, address receiver) internal view returns (bytes memory data) {
        data = CalldataLib.encodeSweep(
            asset,
            receiver,
            amount, //
            SweepType.AMOUNT
        );

        data = CalldataLib.encodeExternalCall(address(cf), amount, false, data);
    }

    function test_unit_externalCall_extCall() external {
        vm.assume(user != address(0));

        address tokenIn = address(0);
        // address tokenOut = WETH;

        uint256 amount = 100.0e6;
        deal(user, amount);

        bytes memory genericData = extCall(
            tokenIn,
            amount,
            user //
        );

        vm.prank(user);
        oneDV2.deltaCompose{value: amount}(genericData);
    }
}
