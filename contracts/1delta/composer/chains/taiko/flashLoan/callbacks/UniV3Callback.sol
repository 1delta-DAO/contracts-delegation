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
    bytes32 private constant UNISWAP_V3_FF_FACTORY = 0xff75fc67473a91335b5b8f8821277262a13b38c9b30000000000000000000000;
    bytes32 private constant UNISWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant DTX_FF_FACTORY = 0xfffca1aef282a99390b62ca8416a68f5747716260c0000000000000000000000;
    bytes32 private constant DTX_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant TAIKOSWAP_V3_FF_FACTORY = 0xff826d713e30f0bf09dd3219494a508e6b30327d4f0000000000000000000000;
    bytes32 private constant TAIKOSWAP_V3_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    bytes32 private constant UNAGI_V3_FF_FACTORY = 0xff78172691dd3b8ada7aebd9bffb487fb11d735db20000000000000000000000;
    bytes32 private constant UNAGI_V3_CODE_HASH = 0x5ccd5621c1bb9e44ce98cef8b90d31eb2423dec3793b6239232cefae976936ea;
    bytes32 private constant PANKO_FF_FACTORY = 0xff7dd105453d0aef177743f5461d7472cc779e63f70000000000000000000000;
    bytes32 private constant PANKO_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
    bytes32 private constant SWAPSICLE_FF_FACTORY = 0xffb68b27a1c93a52d698eeca5a759e2e4469432c09ffffffffffffffffffffff;
    bytes32 private constant SWAPSICLE_CODE_HASH = 0xf96d2474815c32e070cd63233f06af5413efc5dcb430aee4ff18cc29007c562d;
    bytes32 private constant HENJIN_FF_FACTORY = 0xff0d22b434e478386cd3564956bfc722073b3508f6ffffffffffffffffffffff;
    bytes32 private constant HENJIN_CODE_HASH = 0x4b9e4a8044ce5695e06fce9421a63b6f5c3db8a561eebb30ea4c775469e36eaf;

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
                case 10 {
                    ffFactoryAddress := DTX_FF_FACTORY
                    codeHash := DTX_CODE_HASH
                }
                case 11 {
                    ffFactoryAddress := TAIKOSWAP_V3_FF_FACTORY
                    codeHash := TAIKOSWAP_V3_CODE_HASH
                }
                case 20 {
                    ffFactoryAddress := UNAGI_V3_FF_FACTORY
                    codeHash := UNAGI_V3_CODE_HASH
                }
                default {
                    mstore(0, BAD_POOL)
                    revert(0, 0x4)
                }
            }
            case 1 {
                switch and(UINT8_MASK, shr(88, calldataload(172)))
                case 1 {
                    ffFactoryAddress := PANKO_FF_FACTORY
                    codeHash := PANKO_CODE_HASH
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
                case 2 {
                    ffFactoryAddress := HENJIN_FF_FACTORY
                    codeHash := HENJIN_CODE_HASH
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

