// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

/**
 * Author: Achthar | 1delta
 * /*****************************************************************************
 */
import {ValidatorLib} from "../../../../swappers/callbacks/ValidatorLib.sol";
import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Contract Module for general Margin Trading on an borrow delegation compatible Lender
 * @notice Contains main logic for uniswap-type callbacks and initiator functions
 */
abstract contract UniV2Callbacks is Masks, DeltaErrors {
    // factories

    bytes32 private constant STELLASWAP_V2_FF_FACTORY = 0xff68A384D826D3678f78BB9FB1533c7E9577dACc0E0000000000000000000000;
    bytes32 private constant STELLASWAP_V2_CODE_HASH = 0x48a6ca3d52d0d0a6c53a83cc3c8688dd46ea4cb786b169ee959b95ad30f61643;

    bytes32 private constant CONVERGENCE_FF_FACTORY = 0xff9504d0D43189D208459e15c7f643aAC1ABE3735d0000000000000000000000;
    bytes32 private constant CONVERGENCE_CODE_HASH = 0xcde9b0c75e2a4c1e9b2c8de91a208ff4917080e1dd07917fa1c80a02bc362374;

    bytes32 private constant ZENLINK_FF_FACTORY = 0xff079710316b06BBB2c0FF4bEFb7D2DaC206c716A00000000000000000000000;
    bytes32 private constant ZENLINK_CODE_HASH = 0x4d57d13eb6abe5cc425bd08deb1f15f0562098dddc340a700527b4d98f95f4dd;

    bytes32 private constant BEAMSWAP_V2_FF_FACTORY = 0xff985BcA32293A7A496300a48081947321177a86FD0000000000000000000000;
    bytes32 private constant BEAMSWAP_V2_CODE_HASH = 0xe31da4209ffcce713230a74b5287fa8ec84797c9e77e1f7cfeccea015cdc97ea;

    bytes32 private constant SUSHISWAP_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 private constant SUSHISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant SOLARFLARE_FF_FACTORY = 0xff19B85ae92947E0725d5265fFB3389e7E4F191FDa0000000000000000000000;
    bytes32 private constant SOLARFLARE_CODE_HASH = 0xe21386787732ef8059a646602f85a5ebb23848cddd90ef5a8d111ec84a4cb71f;

    bytes32 private constant PADSWAP_FF_FACTORY = 0xff663a07a2648296f1A3C02EE86A126fE1407888E50000000000000000000000;
    bytes32 private constant PADSWAP_CODE_HASH = 0x3eb475f0bc063c4f457199bae925b27d909f4af70ef7db78ba734972fc1a8543;

    /**
     * Generic Uniswap v2 style callbck executor
     */
    function _executeUniV2IfSelector(bytes32 selector) internal {
        bytes32 codeHash;
        bytes32 ffFactoryAddress;
        // this is a data strip that contains [tokenOut(20)|forkId(1)|calldataLength(2)|xxx...xxx(9)]
        bytes32 outData;
        uint256 forkId;
        assembly {
            outData := calldataload(204)
            switch selector
            case 0xd3f7e53900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := STELLASWAP_V2_FF_FACTORY
                codeHash := STELLASWAP_V2_CODE_HASH
            }
            case 0xdf9aee6800000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := CONVERGENCE_FF_FACTORY
                codeHash := CONVERGENCE_CODE_HASH
            }
            case 0xc919dcf000000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := ZENLINK_FF_FACTORY
                codeHash := ZENLINK_CODE_HASH
            }
            case 0x99f9fa5100000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := BEAMSWAP_V2_FF_FACTORY
                codeHash := BEAMSWAP_V2_CODE_HASH
            }
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
                case 10 {
                    ffFactoryAddress := SOLARFLARE_FF_FACTORY
                    codeHash := SOLARFLARE_CODE_HASH
                }
                default { revert(0, 0) }
            }
            case 0x8480081200000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := PADSWAP_FF_FACTORY
                codeHash := PADSWAP_CODE_HASH
            }
        }

        if (ValidatorLib._hasData(ffFactoryAddress)) {
            uint256 calldataLength;
            address callerAddress;
            assembly {
                // revert if sender param is not this address
                if xor(calldataload(4), address()) {
                    mstore(0, INVALID_CALLER)
                    revert(0, 0x4)
                }

                // get tokens
                let tokenIn := shr(96, calldataload(184))
                let tokenOut := shr(96, outData)

                let ptr := mload(0x40)
                switch lt(tokenIn, tokenOut)
                case 0 {
                    mstore(add(ptr, 0x14), tokenIn)
                    mstore(ptr, tokenOut)
                }
                default {
                    mstore(add(ptr, 0x14), tokenOut)
                    mstore(ptr, tokenIn)
                }
                let salt
                // 128 and higher is solidly
                // 128-130 are reserved for the ones that have no isStable flag
                switch gt(forkId, 130)
                case 1 {
                    mstore8(
                        add(ptr, 0x34),
                        gt(forkId, 191) // store isStable (id>=192)
                    )
                    salt := keccak256(add(ptr, 0x0C), 0x29)
                }
                default { salt := keccak256(add(ptr, 0x0C), 0x28) }
                // calculate pool address in next 4 lines
                mstore(ptr, ffFactoryAddress)
                mstore(add(ptr, 0x15), salt)
                mstore(add(ptr, 0x35), codeHash)

                // verify that the caller is a v2 type pool
                if xor(and(ADDRESS_MASK, keccak256(ptr, 0x55)), caller()) {
                    mstore(0x0, BAD_POOL)
                    revert(0x0, 0x4)
                }

                calldataLength := and(UINT16_MASK, shr(72, outData))
                // get caller address as provided in the call setup
                callerAddress := shr(96, calldataload(164))
            }
            _deltaComposeInternal(
                callerAddress,
                // the naive offset is 164
                // we skip the entire callback validation data
                // that is tokens (+40), caller (+20), dexId (+1) datalength (+2)
                // = 227
                227,
                calldataLength
            );
            // force return
            assembly {
                return(0, 0)
            }
        }
    }

    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
