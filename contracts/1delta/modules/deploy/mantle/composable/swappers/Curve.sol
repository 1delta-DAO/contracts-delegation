// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

/******************************************************************************\
* Author: Achthar | 1delta 
/******************************************************************************/

// solhint-disable max-line-length

/**
 * @title Base swapper contract
 * @notice Contains basic logic for swap executions with DEXs
 */
abstract contract CurveSwapper {

    address internal constant STRATUM_3POOL = 0xD6F312AA90Ad4C92224436a7A4a648d69482e47e;
    address internal constant STRATUM_3POOL_2 = 0x7d3621aCA02B711F5f738C9f21C1bFE294df094d;
    address internal constant STRATUM_ETH_POOL = 0xe8792eD86872FD6D8b74d0668E383454cbA15AFc;

    address internal constant MUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;
    address internal constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;

    constructor() {}


    /**
     * Swaps Stratums Curve fork exact in internally and handles wrapping/unwrapping of mUSD->USDY
     * This one has a dedicated implementation as this pool has a rebasing asset which can be unwrapped
     * The rebasing asset is rarely ever used in other types of swap pools, as such,w e auto wrap / unwrap in case we 
     * use the unwrapped asset as input or output 
     * @param tokenIn input
     * @param tokenOut output
     * @param amountIn sell amount
     * @return amountOut buy amount
     */
    function swapStratum3(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
        assembly {
            // curve forks work with indices, we determine these below
            let indexIn
            let indexOut
            switch tokenIn
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {

                ////////////////////////////////////////////////////
                // Wrap USDY->mUSD before the swap
                ////////////////////////////////////////////////////

                // execute USDY->mUSD wrap
                // selector for wrap(uint256)
                mstore(0xB00, 0xea598cb000000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, amountIn)
                if iszero(call(gas(), MUSD, 0x0, 0xB00, 0x24, 0xB00, 0x0)) {
                    let rdsize := returndatasize()
                    returndatacopy(0xB00, 0, rdsize)
                    revert(0xB00, rdsize)
                }

                ////////////////////////////////////////////////////
                // Fetch mUSD balance of this contract 
                ////////////////////////////////////////////////////

                // selector for balanceOf(address)
                mstore(0xB00, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                // add this address as parameter
                mstore(0xB04, address())
                
                // call to token
                pop(staticcall(gas(), MUSD, 0xB00, 0x24, 0xB00, 0x20))

                // load the retrieved balance
                amountIn := mload(0xB00)
                indexIn := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexIn := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexIn := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexIn := 2
            }
            default {
                revert(0, 0)
            }

            switch tokenOut
            // USDY
            case 0x5bE26527e817998A7206475496fDE1E68957c5A6 {
                indexOut := 0
            }
            // MUSD
            case 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3 {
                indexOut := 0
            }
            // USDC
            case 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9 {
                indexOut := 1
            }
            // USDT
            case 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE {
                indexOut := 2
            }
            default {
                revert(0, 0)
            }

            ////////////////////////////////////////////////////
            // Execute swap function 
            ////////////////////////////////////////////////////

            // selector for swap(uint8,uint8,uint256,uint256,uint256)
            mstore(0xB00, 0x9169558600000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            mstore(0xB64, 0) // min out is zero, we validate slippage at the end
            mstore(0xB84, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // no deadline
            if iszero(call(gas(), STRATUM_3POOL, 0x0, 0xB00, 0xA4, 0xB00, 0x20)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0, rdsize)
                revert(0xB00, rdsize)
            }

            amountOut := mload(0xB00)

            if eq(tokenOut, USDY) {

                ////////////////////////////////////////////////////
                // tokenOut is USDY, as such, we unwrap mUSD to SUDY
                ////////////////////////////////////////////////////

                // calculate mUSD->USDY unwrap
                // selector for unwrap(uint256)
                mstore(0xB00, 0xde0e9a3e00000000000000000000000000000000000000000000000000000000)
                mstore(0xB04, amountOut)
                if iszero(call(gas(), MUSD, 0x0, 0xB00, 0x24, 0xB00, 0x20)) {
                    let rdsize := returndatasize()
                    returndatacopy(0xB00, 0, rdsize)
                    revert(0xB00, rdsize)
                }
                // selector for balanceOf(address)
                mstore(0xB00, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                // add this address as parameter
                mstore(add(0xB00, 0x4), address())
                // call to token
                pop(staticcall(5000, USDY, 0xB00, 0x24, 0xB00, 0x20))
                // load the retrieved balance
                amountOut := mload(0xB00)
            }
        }
    }

    function swapCurveGeneral(uint256 indexIn, uint256 indexOut, address pool, uint256 amountIn) internal returns (uint256 amountOut) {
        assembly {
            ////////////////////////////////////////////////////
            // Execute swap function 
            ////////////////////////////////////////////////////

            // selector for swap(uint8,uint8,uint256,uint256,uint256)
            mstore(0xB00, 0x9169558600000000000000000000000000000000000000000000000000000000)
            mstore(0xB04, indexIn)
            mstore(0xB24, indexOut)
            mstore(0xB44, amountIn)
            mstore(0xB64, 0) // min out is zero, we validate slippage at the end
            mstore(0xB84, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) // no deadline
            if iszero(call(gas(), pool, 0x0, 0xB00, 0xA4, 0xB00, 0x20)) {
                let rdsize := returndatasize()
                returndatacopy(0xB00, 0, rdsize)
                revert(0xB00, rdsize)
            }

            amountOut := mload(0xB00)
        }
    }
}
