// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../contracts/1delta/modules/shared/Commands.sol";
import "./DeltaSetup.f.sol";

interface ISwap {
    function getAmountIn(
        address _tokenOut, //
        uint _amountOut,
        address _sender
    ) external view returns (uint _amountIn);

    function getAmountOut(
        address _tokenIn, //
        uint _amountIn,
        address _sender
    ) external view returns (uint _amountOut);

    function master() external view returns (address);

    function symbol() external view returns (string memory);

    function getReserves() external view returns (uint _reserve0, uint _reserve1);

    function getSwapFee(
        address _sender,
        address _tokenIn,
        address _tokenOut, //
        bytes memory data
    ) external view returns (uint24 _swapFee);
}

contract DTXV1TestTaiko is DeltaSetup {
    uint16 internal constant DTXV1_FEE_DENOM = 10000 - 30;

    function test_taiko_composer_dtx1_exact_in() external {
        address user = testUser;
        uint256 amount = 2000.0e6;
        uint256 amountMin = 0.3e18;

        address assetIn = TokensTaiko.USDC;
        address assetOut = TokensTaiko.WETH;
        deal(assetIn, user, 1e23);

        address pool = testQuoter.v2TypePairAddress(assetIn, assetOut, DexMappingsTaiko.DTXV1);
        bytes memory dataRitsu = getSpotExactInSingleGen2(assetIn, assetOut, DexMappingsTaiko.DTXV1, pool);

        bytes memory data = abi.encodePacked(
            uint8(Commands.SWAP_EXACT_IN),
            user,
            encodeSwapAmountParams(amount, amountMin, false, dataRitsu.length),
            dataRitsu
        );

        vm.prank(user);
        IERC20All(assetIn).approve(address(brokerProxyAddress), amount);

        uint received = IERC20All(assetOut).balanceOf(user);

        vm.prank(user);
        uint gas = gasleft();
        IFlashAggregator(brokerProxyAddress).deltaCompose(data);
        gas = gas - gasleft();
        console.log("gas", gas);

        received = IERC20All(assetOut).balanceOf(user) - received;
        // expect 0.7 TokensTaiko.WETH
        assertApproxEqAbs(693166633333881944, received, 1);
    }

    function getSpotExactInSingleGen2(address tokenIn, address tokenOut, uint8 poolId, address pool) internal pure returns (bytes memory data) {
        uint8 action = 0;
        return abi.encodePacked(tokenIn, action, poolId, pool, DTXV1_FEE_DENOM, tokenOut);
    }
}
