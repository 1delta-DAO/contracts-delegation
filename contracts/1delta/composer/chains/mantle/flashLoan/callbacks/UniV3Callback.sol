// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.34;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Uniswap V3-style flash loan callback
 * @notice Trusts any immutable factory-deployed pool via CREATE2 re-derivation. `flash()` calls
 *         back `msg.sender`, so reaching this callback already proves self-initiation.
 * @custom:calldata-offset-table (the `data` blob echoed by the pool, starting at calldata 132)
 * | Offset | Length (bytes) | Description                  |
 * |--------|----------------|------------------------------|
 * | 132    | 20             | origCaller                   |
 * | 152    | 20             | tokenIn                      |
 * | 172    | 20             | tokenOut                     |
 * | 192    | 1              | forkId                       |
 * | 193    | 2              | fee (ignored for Algebra)    |
 * | 195    | 2              | composeLength                |
 * | 197    | composeLength  | composeOperations            |
 */
contract UniV3FlashLoanCallback is Masks, DeltaErrors {
    // ff-factory + init-code-hash constants (Algebra forks carry the FF complement in the low bytes)
    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff0d922fb1bc191f64970ac40376643808b4b74df90000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant METHLAB_FF_FACTORY = 0xff8f140fc3e9211b8dc2fc1d7ee3292f6817c5dd5d0000000000000000000000;
    bytes32 private constant METHLAB_CODE_HASH = 0xacd26fbb15704ae5e5fe7342ea8ebace020e4fa5ad4a03122ce1678278cf382b;
    bytes32 private constant CRUST_FF_FACTORY = 0xffead128bdf9cff441ef401ec8d18a96b4a2d252520000000000000000000000;
    bytes32 private constant CRUST_CODE_HASH = 0x55664e1b1a13929bcf29e892daf029637225ec5c85a385091b8b31dcca255627;
    bytes32 private constant SWAPSICLE_FF_FACTORY = 0xff9de2dea5c68898eb4cb2deaff357dfb26255a4aaffffffffffffffffffffff;
    bytes32 private constant SWAPSICLE_CODE_HASH = 0x177d5fbf994f4d130c008797563306f1a168dc689f81b2fa23b4396931014d91;

    function uniswapV3FlashCallback(uint256, uint256, bytes calldata) external {
        _onUniV3FlashCallback(0);
    }

    function algebraFlashCallback(uint256, uint256, bytes calldata) external {
        _onUniV3FlashCallback(2);
    }

    /**
     * @notice Shared handler for all V3-style flash callbacks.
     * @dev `family` (Classic=0 / Pancake=1 / Algebra=2) namespaces the forkId switch; the handler
     *      recomputes the pool address from the selected factory, the token pair and the fee, and
     *      reverts unless `caller()` is exactly that pool.
     */
    function _onUniV3FlashCallback(uint256 family) internal {
        address callerAddress;
        uint256 calldataLength;
        assembly {
            let ffFactoryAddress
            let codeHash
            // select the fork: outer switch on family, inner on the forkId byte (calldata 192)
            switch family
            case 0 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 0 {
                    ffFactoryAddress := UNISWAP_V3_FF_FACTORY
                    codeHash := UNISWAP_V3_CODE_HASH
                }
                case 10 {
                    ffFactoryAddress := METHLAB_FF_FACTORY
                    codeHash := METHLAB_CODE_HASH
                }
                case 12 {
                    ffFactoryAddress := CRUST_FF_FACTORY
                    codeHash := CRUST_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            case 2 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 1 {
                    ffFactoryAddress := SWAPSICLE_FF_FACTORY
                    codeHash := SWAPSICLE_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            default {
                mstore(0, BAD_POOL)
                revert(0, 0x4)
            }

            let tokenIn := shr(96, calldataload(152))
            let tokenOutAndFee := calldataload(172)
            let tokenOut := shr(96, tokenOutAndFee)

            let s := mload(0x40)
            mstore(s, ffFactoryAddress)
            let p := add(s, 21)
            // sort the pair for the pool salt
            switch lt(tokenIn, tokenOut)
            case 0 {
                mstore(p, tokenOut)
                mstore(add(p, 32), tokenIn)
            }
            default {
                mstore(p, tokenIn)
                mstore(add(p, 32), tokenOut)
            }
            switch and(FF_ADDRESS_COMPLEMENT, ffFactoryAddress)
            case 0 {
                // classic/pancake: fee is part of the salt
                mstore(add(p, 64), and(UINT16_MASK, shr(72, tokenOutAndFee)))
                mstore(p, keccak256(p, 96))
            }
            default {
                // algebra: no fee in the salt
                mstore(p, keccak256(p, 64))
            }
            p := add(p, 32)
            mstore(p, codeHash)

            // reject any caller that is not the deterministic pool
            if xor(caller(), and(ADDRESS_MASK, keccak256(s, 85))) {
                mstore(0x0, BAD_POOL)
                revert(0x0, 0x4)
            }

            calldataLength := and(UINT16_MASK, shr(56, tokenOutAndFee))
            callerAddress := shr(96, calldataload(132))
        }
        // continue the batch; the compose ops repay principal + fee to the pool
        _deltaComposeInternal(
            callerAddress,
            197, // 132 data start + 65 header (20+20+20+1+2+2)
            calldataLength
        );
        assembly {
            return(0, 0)
        }
    }

    /**
     * @notice Override point for flash loan callbacks to execute compose operations
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}

