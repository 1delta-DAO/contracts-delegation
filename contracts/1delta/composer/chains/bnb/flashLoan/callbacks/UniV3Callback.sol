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
    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xffdb1d10011ad0ff90774d0c6bb92e5c5c8b4461f70000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant SUSHISWAP_V3_FF_FACTORY = 0xff126555dd55a39328f69400d6ae4f782bd4c34abb0000000000000000000000;
    bytes32 private constant SUSHISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant PANCAKESWAP_V3_FF_FACTORY = 0xff41ff9aa7e16b8b1a8a8dc4f0efacd93d02d071c90000000000000000000000;
    bytes32 private constant PANCAKESWAP_V3_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
    bytes32 private constant THENA_FF_FACTORY = 0xffc89f69baa3ff17a842ab2de89e5fc8a8e2cc7358ffffffffffffffffffffff;
    bytes32 private constant THENA_CODE_HASH = 0xd61302e7691f3169f5ebeca3a0a4ab8f7f998c01e55ec944e62cfb1109fd2736;
    bytes32 private constant LITX_FF_FACTORY = 0xff9cf85caac177fb2296dcc68004e1c82a757f95edffffffffffffffffffffff;
    bytes32 private constant LITX_CODE_HASH = 0x6ec6c9c8091d160c0aa74b2b14ba9c1717e95093bd3ac085cee99a49aab294a4;

    function uniswapV3FlashCallback(uint256, uint256, bytes calldata) external {
        _onUniV3FlashCallback(0);
    }

    function pancakeV3FlashCallback(uint256, uint256, bytes calldata) external {
        _onUniV3FlashCallback(1);
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
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V3_FF_FACTORY
                    codeHash := SUSHISWAP_V3_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            case 1 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 0 {
                    ffFactoryAddress := PANCAKESWAP_V3_FF_FACTORY
                    codeHash := PANCAKESWAP_V3_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            case 2 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 5 {
                    ffFactoryAddress := THENA_FF_FACTORY
                    codeHash := THENA_CODE_HASH
                }
                case 10 {
                    ffFactoryAddress := LITX_FF_FACTORY
                    codeHash := LITX_CODE_HASH
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

