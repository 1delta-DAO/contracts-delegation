// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {OneDeltaComposerBase} from "../../../contracts/1delta/composer//chains/base/Composer.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "contracts/utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4626Deposit, encodeErc4646Withdraw
 */
contract SwapHopsLightTest is BaseTest {
    address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant UNI_V2_FACTORY = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address internal constant IZI_FACTORY = 0x8c7d3063579BdB0b90997e18A770eaE32E1eBb08;
    uint256 internal constant forkBlock = 26696865;
    OneDeltaComposerBase oneDV2;

    address internal USDC;
    address internal WETH;
    address internal cbETH;
    address internal cbBTC;
    address internal LBTC;
    address internal constant KEYCAT = 0x9a26F5433671751C3276a065f57e5a02D2817973;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.BASE;

        _init(chainName, forkBlock, true);
        LBTC = chain.getTokenAddress(Tokens.LBTC);
        WETH = chain.getTokenAddress(Tokens.WETH);
        cbETH = chain.getTokenAddress(Tokens.CBETH);
        cbBTC = chain.getTokenAddress(Tokens.CBBTC);
        USDC = chain.getTokenAddress(Tokens.USDC);
        oneDV2 = new OneDeltaComposerBase();
    }

    function multiPath(
        address[] memory assets,
        uint16[] memory fees,
        uint8[] memory dexIds,
        address receiver
    )
        internal
        view
        returns (bytes memory data)
    {
        printPath(assets);
        data = abi.encodePacked(
            uint8(fees.length - 1), // path max index
            uint8(0) // no splits
        );
        for (uint256 i = 0; i < assets.length - 1; i++) {
            address pool;
            if (dexIds[i] == DexTypeMappings.UNISWAP_V3_ID) {
                pool = IF(UNI_FACTORY).getPool(assets[i], assets[i + 1], fees[i]);
            } else {
                pool = IF(IZI_FACTORY).pool(assets[i], assets[i + 1], fees[i]);
            }
            console.log("multiPath pool", pool, dexIds[i], assets[i] < assets[i + 1]);
            address _receiver = i < assets.length - 2 ? address(oneDV2) : receiver;
            if (i == 0) {
                data = abi.encodePacked(
                    data, //
                    uint16(0),
                    // atomic
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
                    uint8(0), // <-- we assume native protocol here
                    fees[i],
                    uint16(0)
                );
            } else {
                data = abi.encodePacked(
                    data, //
                    uint16(0),
                    // atomic
                    assets[i + 1], // nextToken
                    _receiver,
                    dexIds[i],
                    pool,
                    uint8(0), // <-- we assume native protocol here
                    fees[i],
                    uint16(1)
                );
            }
        }
    }

    function printPath(address[] memory assets) internal view {
        console.log("-----------------------------");
        for (uint256 i = 0; i < assets.length; i++) {
            console.log("          |         ");
            console.log(IERC20All(assets[i]).symbol(), assets[i]);
            if (i < assets.length - 1) console.log("          |         ");
        }
        console.log("-----------------------------");
    }

    function getPath_USDC_CBETH()
        internal
        view
        returns (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        )
    {
        assets = new address[](3);
        fees = new uint16[](2);
        dexIds = new uint8[](2);
        assets[0] = USDC;
        assets[1] = WETH;
        assets[2] = cbETH;
        fees[0] = 500;
        fees[1] = 500;
        dexIds[0] = uint8(DexTypeMappings.UNISWAP_V3_ID);
        dexIds[1] = uint8(DexTypeMappings.UNISWAP_V3_ID);
    }

    function get_USDC_CBETH_MultiPathCalldata(
        address receiver //
    )
        internal
        view
        returns (bytes memory data)
    {
        (
            address[] memory assets, //
            uint16[] memory fees,
            uint8[] memory dexIds
        ) = getPath_USDC_CBETH();

        return multiPath(
            assets,
            fees,
            dexIds,
            receiver //
        );
    }

    function test_integ_swap_v3_route_no_splits() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        deal(tokenIn, user, 1000.0e6);
        uint256 amount = 100.0e6;

        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        // route swap no splits
        // USDC -> cbBTC -> WETH
        bytes memory swap = abi.encodePacked(
            abi.encodePacked( //
                uint8(ComposerCommands.SWAPS),
                uint128(amount), //
                uint128(1),
                //
                tokenIn
            ),
            get_USDC_CBETH_MultiPathCalldata(user)
        );

        vm.prank(user);
        oneDV2.deltaCompose(swap);
    }
}
