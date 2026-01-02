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

    bytes32 private constant UNISWAP_V2_FF_FACTORY = 0xff9e5A52f57b3038F1B8EeE45F28b3C1967e22799C0000000000000000000000;
    bytes32 private constant UNISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant SUSHISWAP_V2_FF_FACTORY = 0xffc35DADB65012eC5796536bD9864eD8773aBc74C40000000000000000000000;
    bytes32 private constant SUSHISWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant QUICKSWAP_V2_FF_FACTORY = 0xff5757371414417b8C6CAad45bAeF941aBc7d3Ab320000000000000000000000;
    bytes32 private constant QUICKSWAP_V2_CODE_HASH = 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f;

    bytes32 private constant DFYN_FF_FACTORY = 0xffE7Fb3e833eFE5F9c441105EB65Ef8b261266423B0000000000000000000000;
    bytes32 private constant DFYN_CODE_HASH = 0xf187ed688403aa4f7acfada758d8d53698753b998a3071b06f1b777f4330eaf3;

    bytes32 private constant POLYCAT_FF_FACTORY = 0xff477Ce834Ae6b7aB003cCe4BC4d8697763FF456FA0000000000000000000000;
    bytes32 private constant POLYCAT_CODE_HASH = 0x3cad6f9e70e13835b4f07e5dd475f25a109450b22811d0437da51e66c161255a;

    bytes32 private constant COMETH_FF_FACTORY = 0xff800b052609c355cA8103E06F022aA30647eAd60a0000000000000000000000;
    bytes32 private constant COMETH_CODE_HASH = 0x499154cad90a3563f914a25c3710ed01b9a43b8471a35ba8a66a056f37638542;

    bytes32 private constant APESWAP_FF_FACTORY = 0xffCf083Be4164828f00cAE704EC15a36D7114912840000000000000000000000;
    bytes32 private constant APESWAP_CODE_HASH = 0x511f0f358fe530cda0859ec20becf391718fdf5a329be02f4c95361f3d6a42d8;

    bytes32 private constant WAULTSWAP_FF_FACTORY = 0xffa98ea6356A316b44Bf710D5f9b6b4eA0081409Ef0000000000000000000000;
    bytes32 private constant WAULTSWAP_CODE_HASH = 0x1cdc2246d318ab84d8bc7ae2a3d81c235f3db4e113f4c6fdc1e2211a9291be47;

    bytes32 private constant DYSTOPIA_FF_FACTORY = 0xff1d21Db6cde1b18c7E47B0F7F42f4b3F68b9beeC90000000000000000000000;
    bytes32 private constant DYSTOPIA_CODE_HASH = 0x009bce6d7eb00d3d075e5bd9851068137f44bba159f1cde806a268e20baaf2e8;

    /**
     * @notice Generic Uniswap V2 style callback executor
     * @dev Validates the callback selector and executes compose operations
     * @param selector The function selector to match
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 4              | selector                     |
     * | 4      | 20             | sender (must be this)        |
     * | 24     | 140            | callbackData                 |
     * | 164    | 20             | callerAddress                |
     * | 184    | 20             | tokenIn                      |
     * | 204    | 20             | tokenOut                     |
     * | 224    | 1              | forkId                       |
     * | 225    | 2              | calldataLength               |
     * | 227    | Variable       | composeOperations            |
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
            case 0x10d1e85c00000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))
                switch forkId
                case 0 {
                    ffFactoryAddress := UNISWAP_V2_FF_FACTORY
                    codeHash := UNISWAP_V2_CODE_HASH
                }
                case 1 {
                    ffFactoryAddress := SUSHISWAP_V2_FF_FACTORY
                    codeHash := SUSHISWAP_V2_CODE_HASH
                }
                case 3 {
                    ffFactoryAddress := QUICKSWAP_V2_FF_FACTORY
                    codeHash := QUICKSWAP_V2_CODE_HASH
                }
                case 14 {
                    ffFactoryAddress := DFYN_FF_FACTORY
                    codeHash := DFYN_CODE_HASH
                }
                case 15 {
                    ffFactoryAddress := POLYCAT_FF_FACTORY
                    codeHash := POLYCAT_CODE_HASH
                }
                case 16 {
                    ffFactoryAddress := COMETH_FF_FACTORY
                    codeHash := COMETH_CODE_HASH
                }
                default { revert(0, 0) }
            }
            case 0xbecda36300000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := APESWAP_FF_FACTORY
                codeHash := APESWAP_CODE_HASH
            }
            case 0x485f399400000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := WAULTSWAP_FF_FACTORY
                codeHash := WAULTSWAP_CODE_HASH
            }
            case 0x9a7bff7900000000000000000000000000000000000000000000000000000000 {
                forkId := and(UINT8_MASK, shr(88, outData))

                ffFactoryAddress := DYSTOPIA_FF_FACTORY
                codeHash := DYSTOPIA_CODE_HASH
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

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for swap callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
