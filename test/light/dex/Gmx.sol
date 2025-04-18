// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import "../../../contracts/1delta/modules/light/quoter/QuoterLight.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {DexPayConfig} from "contracts/1delta/modules/light/enums/MiscEnums.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

contract GmxLightTest is BaseTest {
    using CalldataLib for bytes;

    uint256 internal constant forkBlock = 327670897;
    QuoterLight quoter;
    IComposerLike oneDV2;

    address internal constant GMX_POOL = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address internal constant GMX_READER = 0x22199a49A999c351eF7927602CFB187ec3cae489;

    address internal constant KTX_POOL = 0xc657A1440d266dD21ec3c299A8B9098065f663Bb;
    address internal constant KTX_READER = 0xbde9c699e719bb44811252FDb3B37E6D3eDa5a28;

    address internal USDC;
    address internal WETH;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.ARBITRUM_ONE;

        _init(chainName, forkBlock);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC_E);
        oneDV2 = ComposerPlugin.getComposer(chainName);
        quoter = new QuoterLight();
    }

    function gmxPoolWETHUSDCSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.gmxStyleSwap(
            USDC,
            receiver,
            GMX_POOL,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function ktxPoolWETHUSDCSwap(address receiver, uint256 amount) internal view returns (bytes memory data) {
        // create head config
        data = CalldataLib.swapHead(
            amount,
            1, // amountOut min
            WETH,
            false // no pre param
        );
        // no branching
        data = data.attachBranch(0, 0, hex"");
        data = data.gmxStyleSwap(
            USDC,
            receiver,
            KTX_POOL,
            DexPayConfig.CALLER_PAYS //
        );
    }

    function gmxPoolWETHUSDCQuote(address reader, address pool, bool isGmx) internal view returns (bytes memory data) {
        // no branching
        data = abi.encodePacked(WETH).attachBranch(0, 0, hex"");
        data = isGmx
            ? data.gmxStyleSwap(
                USDC,
                reader,
                pool,
                DexPayConfig.CALLER_PAYS //
            )
            : data.ktxStyleSwap(
                USDC,
                reader,
                pool,
                DexPayConfig.CALLER_PAYS //
            );
    }

    function test_light_swap_gmx_single() external {
        vm.assume(user != address(0));

        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.01e18;
        uint256 approxOut = 15785207; // 15.785207
        deal(tokenIn, user, amount);

        uint256 quoted = quoter.quote(amount, gmxPoolWETHUSDCQuote(GMX_READER, GMX_POOL, true));
        console.log("quoted", quoted);
        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = gmxPoolWETHUSDCSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, quoted, 0);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }

    function test_light_swap_ktx_single() external {
        vm.assume(user != address(0));
        address tokenIn = WETH;
        address tokenOut = USDC;
        uint256 amount = 0.000001e18;
        uint256 approxOut = 1581; // 0.001581
        deal(tokenIn, user, amount);

        uint256 quoted = quoter.quote(amount, gmxPoolWETHUSDCQuote(KTX_READER, KTX_POOL, false));
        console.log("quoted", quoted);
        vm.prank(user);
        IERC20All(tokenIn).approve(address(oneDV2), type(uint256).max);

        bytes memory swap = ktxPoolWETHUSDCSwap(
            user,
            amount //
        );

        uint256 balBefore = IERC20All(tokenOut).balanceOf(user);
        vm.prank(user);
        oneDV2.deltaCompose(swap);

        uint256 balAfter = IERC20All(tokenOut).balanceOf(user);
        console.log("received", balAfter - balBefore);
        assertApproxEqAbs(balAfter - balBefore, quoted, 0);
        assertApproxEqAbs(balAfter - balBefore, approxOut, (approxOut * 10) / 100);
    }
}
