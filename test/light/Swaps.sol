// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MarketParams, IMorphoEverything} from "./utils/Morpho.sol";

import {OneDeltaComposerLight} from "../../contracts/1delta/modules/light/Composer.sol";
import {IERC20All} from "../shared/interfaces/IERC20All.sol";
import {AAVE_V3_DATA_8453} from "./data/AAVE_V3_DATA_8453.sol";
import "./utils/CalldataLib.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, erc4646Deposit, erc4646Withdraw
 */
contract SwapsLightTest is Test, AAVE_V3_DATA_8453 {
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    OneDeltaComposerLight oneDV2;

    address internal constant user = address(984327);

    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;

    function setUp() public virtual {
        vm.createSelectFork({blockNumber: 26696865, urlOrAlias: "https://mainnet.base.org"});
        oneDV2 = new OneDeltaComposerLight();
    }

    function v3poolSwap(
        address assetIn,
        address assetOut, //
        uint16 fee,
        address receiver,
        uint256 amount
    ) internal view returns (bytes memory data) {
        address pool = IF(UNI_FACTORY).getPool(assetIn, assetOut, fee);
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint8(0), // splits
            assetIn,
            assetOut,
            fee,
            pool,
            receiver,
            uint112(amount) //
        ); // 2 + 20 + 20 + 14 = 56 bytes
    }

    function test_light_swap_v3() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        uint16 fee = 500;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint).max);

        bytes memory swap = v3poolSwap(
            tokenIn,
            tokenOut,
            fee,
            address(oneDV2),
            amount //
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }

}
