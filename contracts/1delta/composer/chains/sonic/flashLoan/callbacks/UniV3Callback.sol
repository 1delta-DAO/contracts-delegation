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
    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xffcb2436774c3e191c85056d248ef4260ce5f27a9d0000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant SOLIDLY_V3_FF_FACTORY = 0xff777faca731b17e8847ebf175c94dbe9d81a8f6300000000000000000000000;
    bytes32 private constant SOLIDLY_V3_CODE_HASH = 0xe9b68c5f77858eecac2e651646e208175e9b1359d68d0e14fc69f8c54e5010bf;
    bytes32 private constant WAGMI_FF_FACTORY = 0xff56cfc796bc88c9c7e1b38c2b0af9b7120b079aef0000000000000000000000;
    bytes32 private constant WAGMI_CODE_HASH = 0x30146866f3a846fe3c636beb2756dbd24cf321bc52c9113c837c21f47470dfeb;
    bytes32 private constant SWAPX_FF_FACTORY = 0xff885229e48987ea4c68f0aa1bcbff5184198a9188ffffffffffffffffffffff;
    bytes32 private constant SWAPX_CODE_HASH = 0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d;

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
                case 2 {
                    ffFactoryAddress := SOLIDLY_V3_FF_FACTORY
                    codeHash := SOLIDLY_V3_CODE_HASH
                }
                case 15 {
                    ffFactoryAddress := WAGMI_FF_FACTORY
                    codeHash := WAGMI_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            case 2 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 22 {
                    ffFactoryAddress := SWAPX_FF_FACTORY
                    codeHash := SWAPX_CODE_HASH
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

