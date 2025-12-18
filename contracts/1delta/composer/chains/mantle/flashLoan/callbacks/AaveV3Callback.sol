// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Masks} from "../../../../../shared/masks/Masks.sol";
import {DeltaErrors} from "../../../../../shared/errors/Errors.sol";

/**
 * @title Take an Aave v3 flash loan callback
 */
contract AaveV3FlashLoanCallback is Masks, DeltaErrors {
    // Aave V3 style lender pool addresses
    address private constant KINZA = 0x5757b15f60331eF3eDb11b16ab0ae72aE678Ed51;
    address private constant LENDLE_CMETH = 0xd9a41322336133f2b026a65F2426647BD0Bf690C;
    address private constant LENDLE_PT_CMETH = 0x5d7b73f9271c40ff737f98B8F818e7477761041f;
    address private constant LENDLE_SUSDE = 0xA9c90b947a45E70451a9C16a8D5BeC2F855DbD1d;
    address private constant LENDLE_SUSDE_USDT = 0x82ca5d1117C8499b731423711272C5ad05Ad693a;
    address private constant LENDLE_METH_WETH = 0x9CdF3c151BE88921544902088fdb54DDf08431d1;
    address private constant LENDLE_METH_USDE = 0xA11A13DE301C3f17c3892786720179750a25450A;
    address private constant LENDLE_CMETH_WETH = 0x6815B0570ea49ccC09F4d910787b0993013DBDAA;
    address private constant LENDLE_CMETH_USDE = 0xEE50fb458a41C628E970657e6d0f01728c64545D;
    address private constant LENDLE_CMETH_WMNT = 0x256eCC6C2b013BFc8e5Af0AD9DF8ebd10122d018;
    address private constant LENDLE_FBTC_WETH = 0x9f2eb80B3c49A5037Fa97d9Ff85CdE1cE45A7fa0;
    address private constant LENDLE_FBTC_USDE = 0x42C5EbFD934923Cc2aB6a3FD91A0d92B6064DFBc;
    address private constant LENDLE_FBTC_WMNT = 0x5CAd26932A8D17Ba0540EeeCb3ABAdf7722DA9a0;
    address private constant LENDLE_WMNT_WETH = 0xeaFF9A5F8676D20F5F1C391902d9584C1b6f33f5;
    address private constant LENDLE_WMNT_USDE = 0xecce86d3D3f1b33Fe34794708B7074CDe4aBe9d4;

    /**
     * @notice Handles Aave V3 flash loan callback
     * @dev Validates caller, extracts original caller from params, and executes compose operations
     * @param initiator The address that initiated the flash loan
     * @return Always returns true on success
     * @custom:calldata-offset-table
     * | Offset | Length (bytes) | Description                  |
     * |--------|----------------|------------------------------|
     * | 0      | 20             | origCaller                   |
     * | 20     | 1              | poolId                       |
     * | 21     | Variable       | composeOperations           |
     */
    function executeOperation(
        address,
        uint256,
        uint256,
        address initiator,
        bytes calldata params // user params
    )
        external
        returns (bool)
    {
        address origCaller;
        uint256 calldataLength;
        assembly {
            calldataLength := params.length

            // validate caller
            // - extract id from params
            let firstWord := calldataload(196)

            // We check that the caller is one of the lending pools
            // This is a crucial check since this makes
            // the initiator parameter the caller of flashLoan
            let pool
            let poolId := and(UINT8_MASK, shr(88, firstWord))

            switch lt(poolId, 105)
            case 1 {
                switch poolId
                case 82 { pool := KINZA }
                case 102 { pool := LENDLE_CMETH }
                case 103 { pool := LENDLE_PT_CMETH }
                case 104 { pool := LENDLE_SUSDE }
            }
            default {
                switch lt(poolId, 109)
                case 1 {
                    switch poolId
                    case 105 { pool := LENDLE_SUSDE_USDT }
                    case 106 { pool := LENDLE_METH_WETH }
                    case 107 { pool := LENDLE_METH_USDE }
                    case 108 { pool := LENDLE_CMETH_WETH }
                }
                default {
                    switch poolId
                    case 109 { pool := LENDLE_CMETH_USDE }
                    case 110 { pool := LENDLE_CMETH_WMNT }
                    case 111 { pool := LENDLE_FBTC_WETH }
                    case 112 { pool := LENDLE_FBTC_USDE }
                    case 113 { pool := LENDLE_FBTC_WMNT }
                    case 114 { pool := LENDLE_WMNT_WETH }
                    case 115 { pool := LENDLE_WMNT_USDE }
                }
            }

            // catch unassigned pool / bad poolId
            if iszero(pool) {
                mstore(0, INVALID_FLASH_LOAN)
                revert(0, 0x4)
            }
            // match pool address
            if xor(caller(), pool) {
                mstore(0, INVALID_CALLER)
                revert(0, 0x4)
            }

            // We require to self-initiate
            // this prevents caller impersonation,
            // but ONLY if the caller address is
            // an Aave V3 type lending pool
            if xor(address(), initiator) {
                mstore(0, INVALID_INITIATOR)
                revert(0, 0x4)
            }
            // Slice the original caller off the beginning of the calldata
            // From here on we have validated that the origCaller
            // was attached in the deltaCompose function
            // Otherwise, this would be a vulnerability
            origCaller := shr(96, firstWord)
            // shift / slice params
            calldataLength := sub(calldataLength, 21)
        }
        // within the flash loan, any compose operation
        // can be executed
        _deltaComposeInternal(
            origCaller,
            217, // 196 +21 as constant offset
            calldataLength
        );
        return true;
    }

    /**
     * @notice Internal function to execute compose operations
     * @dev Override point for flash loan callbacks to execute compose operations
     * @param callerAddress Address of the original caller
     * @param offset Current calldata offset
     * @param length Length of remaining calldata
     */
    function _deltaComposeInternal(address callerAddress, uint256 offset, uint256 length) internal virtual {}
}
