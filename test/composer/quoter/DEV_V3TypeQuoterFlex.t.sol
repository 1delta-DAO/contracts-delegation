// SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.28;

// import {console} from "forge-std/console.sol";
// import "forge-std/Test.sol";
// import "../../../contracts/1delta/composer//quoter/QuoterLight.sol";
// import "../../shared/BaseTest.sol";
// import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
// import {DexTypeMappings} from "../../../contracts/1delta/composer//swappers/dex/DexTypeMappings.sol";
// import {CalldataLib} from "../utils/CalldataLib.sol";
// import {DexPayConfig} from "contracts/1delta/composer/enums/MiscEnums.sol";
// import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// interface IF {
//     function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
// }

// interface IERC20 {
//     function balanceOf(address account) external view returns (uint256);

//     function approve(address spender, uint256 value) external returns (bool);
// }

// contract DEX______V3QuoterTest is BaseTest {
//     using CalldataLib for bytes;

//     uint256 internal constant forkBlock = 1116504;

//     address internal constant UNI_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

//     QuoterLight quoter;
//     IComposerLike composer;

//     address internal WETH;
//     address internal USDC;

//     address internal WETH_USDC_500_POOL;

//     function setUp() public virtual {
//         string memory chainName = Chains.TAIKO_ALETHIA;

//         _init(chainName, forkBlock, true);

//         // WETH = chain.getTokenAddress(Tokens.WETH);
//         // USDC = chain.getTokenAddress(Tokens.USDC);

//         quoter = new QuoterLight();
//         // composer = ComposerPlugin.getComposer(chainName);

//         // deal(WETH, address(user), 10 ether);
//         // deal(USDC, address(user), 1000e6);

//         // // Approve composer
//         // vm.startPrank(user);
//         // IERC20(WETH).approve(address(composer), type(uint256).max);
//         // IERC20(USDC).approve(address(composer), type(uint256).max);
//         // vm.stopPrank();
//     }

//     /**
//      * END OF CALLDATA UTILS
//      */
//     function test_light_quoter_simple_swap_v3_op() public {
//         /**
//          * WETH -> USDC (0,0)
//          */
//         uint256 amountIn = 1 * 1e18; // 1 WETH
//         console.logBytes4(bytes4(keccak256(("zfV3SwapCallback(int256,int256,bytes)"))));

//         // Use utility function to encode path
//         bytes memory path =
//             hex"a9d23408b9ba935c230493c40c73824df71a09750000a51894664a773981c6c112c43ce576f315d5b1b6000000000000000000000000000000000000000000622f6796aeb2447edc31e9f0cf599b65018f8d70140bb80000";
//         // single swap branch (0,0)
//         bytes memory swapBranch = (new bytes(0)).attachBranch(0, 0, ""); //(0,0)
//         uint256 gas = gasleft();
//         // Get quote
//         uint256 quotedAmountOut = quoter.quote(amountIn, path);

//         gas = gas - gasleft();
//         console.log("gas", gas);

//         console.log("Quoted amount:", quotedAmountOut);

//         // // add quotedAmountOut as amountOutMin
//         // bytes memory swapHead = CalldataLib.swapHead(amountIn, quotedAmountOut, WETH);
//         // bytes memory swapCall = CalldataLib.encodeUniswapV3StyleSwap(
//         //     abi.encodePacked(swapHead, swapBranch), USDC, user, 0, WETH_USDC_500_POOL, 500, DexPayConfig.CALLER_PAYS, ""
//         // );

//         // // Get actual amount from a real swap
//         // uint256 balanceBefore = IERC20(USDC).balanceOf(address(user));

//         // gas = gasleft();

//         // vm.prank(user);
//         // composer.deltaCompose(abi.encodePacked(swapCall));

//         // gas = gas - gasleft();
//         // console.log("gas", gas);

//         // uint256 balanceAfter = IERC20(USDC).balanceOf(address(user));
//         // uint256 actualAmountOut = balanceAfter - balanceBefore;

//         // // Compare results
//         // assertApproxEqRel(quotedAmountOut, actualAmountOut, 1, "didn't work");
//         // console.log("Quote amount:", quotedAmountOut);
//         // console.log("Actual amount:", actualAmountOut);
//     }

//     function multiPath(address[] memory assets, uint16[] memory fees, address receiver) internal view returns (bytes memory data) {
//         data = abi.encodePacked(
//             uint8(fees.length - 1), // path max index
//             uint8(0) // no splits
//         );
//         for (uint256 i = 0; i < assets.length - 1; i++) {
//             address pool = IF(UNI_FACTORY).getPool(assets[i], assets[i + 1], fees[i]);

//             address _receiver = i < assets.length - 2 ? address(quoter) : receiver;
//             data = abi.encodePacked(
//                 data, //
//                 uint8(0),
//                 uint8(0),
//                 assets[i + 1], // nextToken
//                 _receiver,
//                 uint8(DexTypeMappings.UNISWAP_V3_ID),
//                 pool,
//                 uint8(0), // <-- we assume native protocol here
//                 fees[i],
//                 uint16(DexPayConfig.CALLER_PAYS),
//                 new bytes(0)
//             );
//             // console.log("Path: ", i);
//             // console.logBytes(data);
//         }

//         return data;
//     }
// }
