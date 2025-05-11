// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20All} from "../../shared/interfaces/IERC20All.sol";
import {BaseTest} from "../../shared/BaseTest.sol";
import {Chains, Tokens, Lenders} from "../../data/LenderRegistry.sol";
import "../utils/CalldataLib.sol";
import {ComposerPlugin, IComposerLike} from "plugins/ComposerPlugin.sol";

// solhint-disable max-line-length

interface IF {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
    function getPool(address tokenA, address tokenB, int24 fee) external view returns (address);

    function pool(address tokenA, address tokenB, uint24 fee) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function getPair(address tokenA, address tokenB, bool isStable) external view returns (address pair);
}

/**
 * We test all morpho blue operations
 * - supply, supplyCollateral, borrow, repay, encodeErc4646Deposit, encodeErc4646Withdraw
 */
contract MoeV1Test is BaseTest {
    address internal constant MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    uint256 internal constant forkBlock = 78734481;
    IComposerLike oneDV2;

    string internal lender;

    address internal USDC;
    address internal WETH;
    address internal LENDLE_POOL;

    function setUp() public virtual {
        // initialize the chain
        string memory chainName = Chains.MANTLE;
        lender = Lenders.LENDLE;

        _init(chainName, forkBlock, true);
        WETH = chain.getTokenAddress(Tokens.WETH);
        USDC = chain.getTokenAddress(Tokens.USDC);
        LENDLE_POOL = chain.getLendingController(lender);
        oneDV2 = ComposerPlugin.getComposer(chainName);
    }

    function v2poolFlashSwap(
        address assetIn,
        address assetOut, //
        uint8 dexId,
        address receiver,
        uint256 amount,
        bytes memory callbackData
    )
        internal
        view
        returns (bytes memory data)
    {
        address pool = IF(MOE_FACTORY).getPair(assetIn, assetOut);
        console.log("pool", pool);
        data = abi.encodePacked(
            uint8(ComposerCommands.SWAPS),
            uint128(amount), //
            uint128(1),
            //
            assetIn,
            uint8(0), // swaps max index
            uint8(0) // splits
                // single split data (no data here)
                // uint8(0), // swaps max index for inner path
        );
        console.log("callbackData.length", callbackData.length);
        console.logBytes(callbackData);
        data = abi.encodePacked(
            data,
            assetOut,
            receiver,
            dexId,
            // v2 pool data
            pool,
            uint16(9970), // fee denom
            uint8(0), // moe is zero
            uint16(callbackData.length), // cll length <- user pays
            callbackData
        );
    }

    /**
     * Flash swap open on aave v3 using Velodrome V2
     */
    function test_light_aave_flash_swap_moe1_single() external {
        vm.assume(user != address(0));

        address tokenIn = USDC;
        address tokenOut = WETH;
        address pool = LENDLE_POOL;
        uint256 amount = 0.1e18;
        uint256 borrowAmount = 200.0e6;
        deal(tokenOut, user, 0.1e18);

        depositToAave(tokenOut, user, amount, pool);

        address vToken = _getDebtToken(tokenIn);

        vm.prank(user);
        IERC20All(vToken).approveDelegation(address(oneDV2), type(uint256).max);

        address uniPool = IF(MOE_FACTORY).getPair(tokenIn, tokenOut);

        // console.log("moePair", moePair(tokenIn, tokenOut));
        // borrow and deposit with override amounts (optimal)
        bytes memory borrow = CalldataLib.encodeAaveBorrow(tokenIn, borrowAmount, uniPool, 2, pool);
        bytes memory action = CalldataLib.encodeAaveV2Deposit(tokenOut, 0, user, pool);

        action = v2poolFlashSwap(
            tokenIn,
            tokenOut, //
            uint8(DexTypeMappings.UNISWAP_V2_ID),
            address(oneDV2),
            borrowAmount,
            abi.encodePacked(action, borrow)
        );

        vm.prank(user);
        oneDV2.deltaCompose(action);
    }

    // immutable cone based address calculator
    // function moePair(address tokenIn, address tokenOut) internal pure returns (address pool) {
    //     bytes32 data;
    //     console.log("tokenIn", tokenIn);
    //     console.log("tokenOut", tokenOut);
    //     assembly {
    //         let ptr := mload(0x40)
    //         mstore(ptr, 0x61005f3d81600a3d39f3363d3d373d3d3d3d61002a806035363936013d730847)
    //         mstore(add(ptr, 0x20), 0x7e01a19d44c31e4c11dc2ac86e3bbe69c28b5af43d3d93803e603357fd5bf300)

    //         switch lt(tokenIn, tokenOut)
    //         case 0 {
    //             mstore(add(ptr, 63), shl(96, tokenOut))
    //             mstore(add(ptr, 83), shl(96, tokenIn))
    //         }
    //         default {
    //             mstore(add(ptr, 63), shl(96, tokenIn))
    //             mstore(add(ptr, 83), shl(96, tokenOut))
    //         }
    //         data := mload(add(ptr, 83))
    //         let salt := keccak256(add(ptr, 63), 0x28)
    //         mstore(add(ptr, 103), 0x002a000000000000000000000000000000000000000000000000000000000000)
    //         let _codeHash := keccak256(ptr, 105)

    //         mstore(ptr, 0xff5bEf015CA9424A7C07B68490616a4C1F094BEdEc0000000000000000000000)
    //         mstore(add(ptr, 0x15), salt)
    //         mstore(add(ptr, 0x35), _codeHash)
    //         pool := and(0x00ffffffffffffffffffffffffffffffffffffffff, keccak256(ptr, 0x55))
    //     }
    //     console.logBytes32(data);
    // }

    function depositToAave(address token, address userAddress, uint256 amount, address pool) internal {
        deal(token, userAddress, amount);

        vm.prank(userAddress);
        IERC20All(token).approve(address(oneDV2), type(uint256).max);

        bytes memory transferTo = CalldataLib.encodeTransferIn(
            token,
            address(oneDV2),
            amount //
        );

        bytes memory d = CalldataLib.encodeAaveV2Deposit(token, amount, userAddress, pool);

        vm.prank(userAddress);
        oneDV2.deltaCompose(abi.encodePacked(transferTo, d));
    }

    function _getDebtToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).debt;
    }

    function _getCollateralToken(address token) internal view returns (address) {
        return chain.getLendingTokens(token, lender).collateral;
    }
}
